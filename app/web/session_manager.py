"""
Session Manager
===============
Gerencia sessões de chat com persistência e histórico.
"""

import asyncio
import json
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

try:
    from app.config import PROJECT_ROOT
    from app.logger import logger
except Exception:
    PROJECT_ROOT = Path(__file__).parent.parent.parent
    import logging
    logger = logging.getLogger(__name__)


class Session:
    """Representa uma sessão de chat."""
    
    def __init__(self, session_id: Optional[str] = None):
        self.id = session_id or str(uuid.uuid4())
        self.created_at = datetime.now()
        self.updated_at = datetime.now()
        self.status = "idle"  # idle, processing, completed, error, stopped
        self.messages: List[Dict[str, Any]] = []
        self.thinking_steps: List[Dict[str, Any]] = []
        self.files: List[str] = []
        self.metadata: Dict[str, Any] = {}
        self.error: Optional[str] = None
    
    def add_message(self, role: str, content: str, metadata: Optional[Dict] = None):
        """Adiciona uma mensagem à sessão."""
        message = {
            "id": str(uuid.uuid4()),
            "role": role,
            "content": content,
            "timestamp": datetime.now().isoformat(),
            "metadata": metadata or {}
        }
        self.messages.append(message)
        self.updated_at = datetime.now()
        return message
    
    def add_thinking_step(self, step: str, tool: Optional[str] = None):
        """Adiciona um passo de pensamento."""
        thinking = {
            "id": str(uuid.uuid4()),
            "step": step,
            "tool": tool,
            "timestamp": datetime.now().isoformat()
        }
        self.thinking_steps.append(thinking)
        self.updated_at = datetime.now()
        return thinking
    
    def set_status(self, status: str, error: Optional[str] = None):
        """Define o status da sessão."""
        self.status = status
        self.error = error
        self.updated_at = datetime.now()
    
    def add_file(self, file_path: str):
        """Adiciona um arquivo à sessão."""
        if file_path not in self.files:
            self.files.append(file_path)
            self.updated_at = datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """Converte a sessão para dicionário."""
        return {
            "id": self.id,
            "created_at": self.created_at.isoformat(),
            "updated_at": self.updated_at.isoformat(),
            "status": self.status,
            "messages": self.messages,
            "thinking_steps": self.thinking_steps,
            "files": self.files,
            "metadata": self.metadata,
            "error": self.error
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Session":
        """Cria uma sessão a partir de um dicionário."""
        session = cls(session_id=data["id"])
        session.created_at = datetime.fromisoformat(data["created_at"])
        session.updated_at = datetime.fromisoformat(data["updated_at"])
        session.status = data["status"]
        session.messages = data["messages"]
        session.thinking_steps = data["thinking_steps"]
        session.files = data["files"]
        session.metadata = data.get("metadata", {})
        session.error = data.get("error")
        return session


class SessionManager:
    """Gerencia sessões de chat."""
    
    def __init__(self, persist: bool = True):
        self.sessions: Dict[str, Session] = {}
        self.persist = persist
        self.sessions_dir = PROJECT_ROOT / "sessions"
        
        if self.persist:
            self._ensure_sessions_dir()
            self._load_sessions()
    
    def _ensure_sessions_dir(self):
        """Garante que o diretório de sessões existe."""
        self.sessions_dir.mkdir(parents=True, exist_ok=True)
    
    def _load_sessions(self):
        """Carrega sessões persistidas."""
        if not self.sessions_dir.exists():
            return
        
        for session_file in self.sessions_dir.glob("*.json"):
            try:
                with open(session_file, "r") as f:
                    data = json.load(f)
                    session = Session.from_dict(data)
                    self.sessions[session.id] = session
            except Exception as e:
                logger.error(f"Erro ao carregar sessão {session_file}: {e}")
    
    def _save_session(self, session: Session):
        """Salva uma sessão no disco."""
        if not self.persist:
            return
        
        try:
            session_file = self.sessions_dir / f"{session.id}.json"
            with open(session_file, "w") as f:
                json.dump(session.to_dict(), f, indent=2)
        except Exception as e:
            logger.error(f"Erro ao salvar sessão {session.id}: {e}")
    
    def create_session(self, metadata: Optional[Dict] = None) -> Session:
        """Cria uma nova sessão."""
        session = Session()
        if metadata:
            session.metadata = metadata
        self.sessions[session.id] = session
        self._save_session(session)
        return session
    
    def get_session(self, session_id: str) -> Optional[Session]:
        """Obtém uma sessão pelo ID."""
        return self.sessions.get(session_id)
    
    def update_session(self, session: Session):
        """Atualiza uma sessão."""
        self.sessions[session.id] = session
        self._save_session(session)
    
    def delete_session(self, session_id: str) -> bool:
        """Remove uma sessão."""
        if session_id in self.sessions:
            del self.sessions[session_id]
            
            if self.persist:
                session_file = self.sessions_dir / f"{session_id}.json"
                if session_file.exists():
                    session_file.unlink()
            
            return True
        return False
    
    def list_sessions(self, limit: int = 50, offset: int = 0) -> List[Dict[str, Any]]:
        """Lista sessões ordenadas por data de atualização."""
        sessions = sorted(
            self.sessions.values(),
            key=lambda s: s.updated_at,
            reverse=True
        )
        
        return [
            {
                "id": s.id,
                "created_at": s.created_at.isoformat(),
                "updated_at": s.updated_at.isoformat(),
                "status": s.status,
                "message_count": len(s.messages),
                "preview": s.messages[0]["content"][:100] if s.messages else ""
            }
            for s in sessions[offset:offset + limit]
        ]
    
    def search_sessions(self, query: str) -> List[Dict[str, Any]]:
        """Busca sessões por conteúdo."""
        results = []
        query_lower = query.lower()
        
        for session in self.sessions.values():
            for message in session.messages:
                if query_lower in message["content"].lower():
                    results.append({
                        "id": session.id,
                        "created_at": session.created_at.isoformat(),
                        "updated_at": session.updated_at.isoformat(),
                        "status": session.status,
                        "match": message["content"][:200]
                    })
                    break
        
        return results
    
    def cleanup_old_sessions(self, days: int = 30):
        """Remove sessões antigas."""
        cutoff = datetime.now().timestamp() - (days * 24 * 60 * 60)
        
        to_delete = []
        for session_id, session in self.sessions.items():
            if session.updated_at.timestamp() < cutoff:
                to_delete.append(session_id)
        
        for session_id in to_delete:
            self.delete_session(session_id)
        
        return len(to_delete)
    
    def get_session_stats(self) -> Dict[str, Any]:
        """Obtém estatísticas das sessões."""
        total = len(self.sessions)
        by_status = {}
        total_messages = 0
        
        for session in self.sessions.values():
            by_status[session.status] = by_status.get(session.status, 0) + 1
            total_messages += len(session.messages)
        
        return {
            "total_sessions": total,
            "by_status": by_status,
            "total_messages": total_messages
        }


# Singleton instance
session_manager = SessionManager()
