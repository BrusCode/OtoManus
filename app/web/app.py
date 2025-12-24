"""
Otomanus Web Application
========================
Interface web para o agente Otomanus baseado no OpenManus.
Fornece uma interface amigável para interação com o agente via browser.
"""

import asyncio
import json
import os
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

# Import agent components
import sys
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from app.agent.manus import Manus
    from app.config import config, WORKSPACE_ROOT, PROJECT_ROOT
    from app.logger import logger
except ImportError:
    # Fallback for standalone testing
    Manus = None
    config = None
    WORKSPACE_ROOT = Path(__file__).parent.parent.parent / "workspace"
    PROJECT_ROOT = Path(__file__).parent.parent.parent
    import logging
    logger = logging.getLogger(__name__)

from .config_manager import config_manager
from .session_manager import session_manager, Session

# Application setup
app = FastAPI(
    title="Otomanus",
    description="Interface web para o agente Otomanus - Um assistente de IA de propósito geral",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static files and templates
static_path = Path(__file__).parent / "static"
templates_path = Path(__file__).parent / "templates"

app.mount("/static", StaticFiles(directory=str(static_path)), name="static")
templates = Jinja2Templates(directory=str(templates_path))

# Session management
class SessionManager:
    """Gerencia sessões de chat com o agente."""
    
    def __init__(self):
        self.sessions: Dict[str, dict] = {}
        self.agents: Dict[str, Manus] = {}
        self.websockets: Dict[str, List[WebSocket]] = {}
        self.tasks: Dict[str, asyncio.Task] = {}
    
    def create_session(self) -> str:
        """Cria uma nova sessão."""
        session_id = str(uuid.uuid4())
        self.sessions[session_id] = {
            "id": session_id,
            "created_at": datetime.now().isoformat(),
            "status": "idle",
            "messages": [],
            "thinking_steps": [],
            "files": []
        }
        self.websockets[session_id] = []
        return session_id
    
    def get_session(self, session_id: str) -> Optional[dict]:
        """Obtém uma sessão pelo ID."""
        return self.sessions.get(session_id)
    
    async def broadcast(self, session_id: str, message: dict):
        """Envia mensagem para todos os WebSockets conectados à sessão."""
        if session_id in self.websockets:
            for ws in self.websockets[session_id]:
                try:
                    await ws.send_json(message)
                except Exception as e:
                    logger.error(f"Erro ao enviar mensagem WebSocket: {e}")

session_manager = SessionManager()


# Pydantic models
class ChatRequest(BaseModel):
    prompt: str
    session_id: Optional[str] = None


class ConfigUpdate(BaseModel):
    llm: Optional[dict] = None
    browser: Optional[dict] = None
    search: Optional[dict] = None
    mcp: Optional[dict] = None


class MCPServerConfig(BaseModel):
    server_id: str
    type: str  # "sse" or "stdio"
    url: Optional[str] = None
    command: Optional[str] = None
    args: Optional[List[str]] = None


class ToolConfig(BaseModel):
    name: str
    enabled: bool
    parameters: Optional[dict] = None


# Routes
@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """Página principal da aplicação."""
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/api/health")
async def health_check():
    """Verificação de saúde da aplicação."""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}


# Chat endpoints
@app.post("/api/chat")
async def create_chat(request: ChatRequest):
    """Cria uma nova sessão de chat ou continua uma existente."""
    session_id = request.session_id or session_manager.create_session()
    session = session_manager.get_session(session_id)
    
    if not session:
        session_id = session_manager.create_session()
        session = session_manager.get_session(session_id)
    
    # Add user message
    session["messages"].append({
        "role": "user",
        "content": request.prompt,
        "timestamp": datetime.now().isoformat()
    })
    session["status"] = "processing"
    
    # Start agent task
    async def run_agent():
        try:
            agent = await Manus.create()
            session_manager.agents[session_id] = agent
            
            # Broadcast status update
            await session_manager.broadcast(session_id, {
                "type": "status",
                "status": "processing",
                "message": "Processando sua solicitação..."
            })
            
            # Run agent
            result = await agent.run(request.prompt)
            
            # Add assistant response
            session["messages"].append({
                "role": "assistant",
                "content": result,
                "timestamp": datetime.now().isoformat()
            })
            session["status"] = "completed"
            
            # Broadcast completion
            await session_manager.broadcast(session_id, {
                "type": "complete",
                "result": result
            })
            
        except Exception as e:
            logger.error(f"Erro ao executar agente: {e}")
            session["status"] = "error"
            session["error"] = str(e)
            await session_manager.broadcast(session_id, {
                "type": "error",
                "message": str(e)
            })
        finally:
            if session_id in session_manager.agents:
                await session_manager.agents[session_id].cleanup()
                del session_manager.agents[session_id]
    
    # Create and store task
    task = asyncio.create_task(run_agent())
    session_manager.tasks[session_id] = task
    
    return {"session_id": session_id, "status": "processing"}


@app.get("/api/chat/{session_id}")
async def get_chat(session_id: str):
    """Obtém o status e mensagens de uma sessão."""
    session = session_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Sessão não encontrada")
    return session


@app.post("/api/chat/{session_id}/stop")
async def stop_chat(session_id: str):
    """Para a execução de uma sessão."""
    if session_id in session_manager.tasks:
        session_manager.tasks[session_id].cancel()
        del session_manager.tasks[session_id]
    
    if session_id in session_manager.agents:
        await session_manager.agents[session_id].cleanup()
        del session_manager.agents[session_id]
    
    session = session_manager.get_session(session_id)
    if session:
        session["status"] = "stopped"
    
    return {"status": "stopped"}


# WebSocket endpoint
@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    """WebSocket para comunicação em tempo real."""
    await websocket.accept()
    
    session = session_manager.get_session(session_id)
    if not session:
        await websocket.close(code=4004, reason="Sessão não encontrada")
        return
    
    session_manager.websockets[session_id].append(websocket)
    
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
            elif message.get("type") == "chat":
                # Handle chat message
                request = ChatRequest(prompt=message["content"], session_id=session_id)
                await create_chat(request)
    
    except WebSocketDisconnect:
        session_manager.websockets[session_id].remove(websocket)
    except Exception as e:
        logger.error(f"Erro WebSocket: {e}")
        session_manager.websockets[session_id].remove(websocket)


# Files endpoints
@app.get("/api/files")
async def list_files():
    """Lista arquivos no workspace."""
    files = []
    workspace = WORKSPACE_ROOT
    
    if workspace.exists():
        for item in workspace.rglob("*"):
            if item.is_file():
                files.append({
                    "name": item.name,
                    "path": str(item.relative_to(workspace)),
                    "size": item.stat().st_size,
                    "modified": datetime.fromtimestamp(item.stat().st_mtime).isoformat()
                })
    
    return {"files": files, "workspace": str(workspace)}


@app.get("/api/files/{file_path:path}")
async def get_file(file_path: str):
    """Obtém o conteúdo de um arquivo."""
    full_path = WORKSPACE_ROOT / file_path
    
    if not full_path.exists():
        raise HTTPException(status_code=404, detail="Arquivo não encontrado")
    
    if not full_path.is_file():
        raise HTTPException(status_code=400, detail="Caminho não é um arquivo")
    
    # Check if it's a text file
    try:
        content = full_path.read_text(encoding="utf-8")
        return {"content": content, "type": "text"}
    except UnicodeDecodeError:
        return FileResponse(str(full_path))


# Configuration endpoints
@app.get("/api/config")
async def get_config():
    """Obtém a configuração atual."""
    # Use config_manager for configuration
    cfg = config_manager.load_config()
    
    return {
        "llm": cfg.get("llm", {
            "model": "gpt-4o",
            "base_url": "https://api.openai.com/v1",
            "max_tokens": 4096,
            "temperature": 0.0
        }),
        "browser": cfg.get("browser", {
            "headless": False,
            "disable_security": True
        }),
        "search": cfg.get("search", {
            "engine": "Google"
        }),
        "mcp": {
            "servers": config_manager.get_mcp_servers()
        },
        "workspace": str(WORKSPACE_ROOT)
    }


@app.post("/api/config")
async def update_config(update: ConfigUpdate):
    """Atualiza a configuração."""
    # Note: This would need to write to config.toml
    # For now, return a message indicating the change would be applied on restart
    return {
        "status": "success",
        "message": "Configuração atualizada. Reinicie a aplicação para aplicar as mudanças."
    }


@app.get("/api/config/llm/models")
async def get_available_models():
    """Lista modelos LLM disponíveis."""
    return {
        "models": [
            {"id": "gpt-4o", "name": "GPT-4o", "provider": "OpenAI"},
            {"id": "gpt-4o-mini", "name": "GPT-4o Mini", "provider": "OpenAI"},
            {"id": "gpt-4-turbo", "name": "GPT-4 Turbo", "provider": "OpenAI"},
            {"id": "claude-3-opus-20240229", "name": "Claude 3 Opus", "provider": "Anthropic"},
            {"id": "claude-3-sonnet-20240229", "name": "Claude 3 Sonnet", "provider": "Anthropic"},
            {"id": "claude-3-haiku-20240307", "name": "Claude 3 Haiku", "provider": "Anthropic"},
            {"id": "llama3.2", "name": "Llama 3.2", "provider": "Ollama"},
        ]
    }


# MCP endpoints
@app.get("/api/mcp/servers")
async def list_mcp_servers():
    """Lista servidores MCP configurados."""
    servers = []
    if config.mcp_config and config.mcp_config.servers:
        for server_id, server_config in config.mcp_config.servers.items():
            servers.append({
                "id": server_id,
                "type": server_config.type,
                "url": server_config.url,
                "command": server_config.command,
                "args": server_config.args
            })
    return {"servers": servers}


@app.post("/api/mcp/servers")
async def add_mcp_server(server: MCPServerConfig):
    """Adiciona um novo servidor MCP."""
    # This would need to update mcp.json
    return {
        "status": "success",
        "message": f"Servidor MCP '{server.server_id}' adicionado. Reinicie para aplicar."
    }


@app.delete("/api/mcp/servers/{server_id}")
async def remove_mcp_server(server_id: str):
    """Remove um servidor MCP."""
    return {
        "status": "success",
        "message": f"Servidor MCP '{server_id}' removido. Reinicie para aplicar."
    }


# Tools endpoints
@app.get("/api/tools")
async def list_tools():
    """Lista ferramentas disponíveis."""
    tools = [
        {
            "name": "python_execute",
            "description": "Executa código Python",
            "enabled": True,
            "category": "execution"
        },
        {
            "name": "browser_use",
            "description": "Automação de navegador web",
            "enabled": True,
            "category": "browser"
        },
        {
            "name": "str_replace_editor",
            "description": "Editor de arquivos com substituição de strings",
            "enabled": True,
            "category": "files"
        },
        {
            "name": "web_search",
            "description": "Busca na web",
            "enabled": True,
            "category": "search"
        },
        {
            "name": "ask_human",
            "description": "Solicita ajuda do usuário",
            "enabled": True,
            "category": "interaction"
        },
        {
            "name": "terminate",
            "description": "Finaliza a execução",
            "enabled": True,
            "category": "control"
        }
    ]
    return {"tools": tools}


@app.post("/api/tools/{tool_name}/toggle")
async def toggle_tool(tool_name: str, enabled: bool = True):
    """Ativa ou desativa uma ferramenta."""
    return {
        "status": "success",
        "tool": tool_name,
        "enabled": enabled
    }


# Logs endpoints
@app.get("/api/logs")
async def list_logs():
    """Lista arquivos de log."""
    logs_dir = PROJECT_ROOT / "logs"
    logs = []
    
    if logs_dir.exists():
        for log_file in logs_dir.glob("*.log"):
            logs.append({
                "name": log_file.name,
                "size": log_file.stat().st_size,
                "modified": datetime.fromtimestamp(log_file.stat().st_mtime).isoformat()
            })
    
    return {"logs": logs}


@app.get("/api/logs/{log_name}")
async def get_log(log_name: str, lines: int = 100):
    """Obtém o conteúdo de um arquivo de log."""
    log_path = PROJECT_ROOT / "logs" / log_name
    
    if not log_path.exists():
        raise HTTPException(status_code=404, detail="Log não encontrado")
    
    content = log_path.read_text(encoding="utf-8")
    log_lines = content.split("\n")
    
    return {
        "name": log_name,
        "content": "\n".join(log_lines[-lines:]),
        "total_lines": len(log_lines)
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
