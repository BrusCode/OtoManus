"""
Configuration Manager
====================
Gerencia configurações dinâmicas do Otomanus via interface web.
"""

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

import toml

try:
    from app.config import PROJECT_ROOT
except Exception:
    PROJECT_ROOT = Path(__file__).parent.parent.parent


class ConfigManager:
    """Gerencia configurações do sistema."""
    
    def __init__(self):
        self.config_dir = PROJECT_ROOT / "config"
        self.config_file = self.config_dir / "config.toml"
        self.mcp_file = self.config_dir / "mcp.json"
        self._config_cache: Optional[Dict] = None
        self._mcp_cache: Optional[Dict] = None
    
    def _ensure_config_dir(self):
        """Garante que o diretório de configuração existe."""
        self.config_dir.mkdir(parents=True, exist_ok=True)
    
    def load_config(self) -> Dict[str, Any]:
        """Carrega a configuração do arquivo TOML."""
        if self._config_cache is not None:
            return self._config_cache
        
        if self.config_file.exists():
            try:
                self._config_cache = toml.load(self.config_file)
            except Exception as e:
                print(f"Erro ao carregar config.toml: {e}")
                self._config_cache = self._get_default_config()
        else:
            self._config_cache = self._get_default_config()
        
        return self._config_cache
    
    def save_config(self, config: Dict[str, Any]) -> bool:
        """Salva a configuração no arquivo TOML."""
        try:
            self._ensure_config_dir()
            with open(self.config_file, "w") as f:
                toml.dump(config, f)
            self._config_cache = config
            return True
        except Exception as e:
            print(f"Erro ao salvar config.toml: {e}")
            return False
    
    def update_config(self, section: str, key: str, value: Any) -> bool:
        """Atualiza uma configuração específica."""
        config = self.load_config()
        
        if section not in config:
            config[section] = {}
        
        config[section][key] = value
        return self.save_config(config)
    
    def get_config_value(self, section: str, key: str, default: Any = None) -> Any:
        """Obtém um valor de configuração específico."""
        config = self.load_config()
        return config.get(section, {}).get(key, default)
    
    def load_mcp_config(self) -> Dict[str, Any]:
        """Carrega a configuração MCP do arquivo JSON."""
        if self._mcp_cache is not None:
            return self._mcp_cache
        
        if self.mcp_file.exists():
            try:
                with open(self.mcp_file, "r") as f:
                    self._mcp_cache = json.load(f)
            except Exception as e:
                print(f"Erro ao carregar mcp.json: {e}")
                self._mcp_cache = self._get_default_mcp_config()
        else:
            self._mcp_cache = self._get_default_mcp_config()
        
        return self._mcp_cache
    
    def save_mcp_config(self, config: Dict[str, Any]) -> bool:
        """Salva a configuração MCP no arquivo JSON."""
        try:
            self._ensure_config_dir()
            with open(self.mcp_file, "w") as f:
                json.dump(config, f, indent=2)
            self._mcp_cache = config
            return True
        except Exception as e:
            print(f"Erro ao salvar mcp.json: {e}")
            return False
    
    def add_mcp_server(self, server_id: str, server_config: Dict[str, Any]) -> bool:
        """Adiciona um servidor MCP."""
        config = self.load_mcp_config()
        
        if "mcpServers" not in config:
            config["mcpServers"] = {}
        
        config["mcpServers"][server_id] = server_config
        return self.save_mcp_config(config)
    
    def remove_mcp_server(self, server_id: str) -> bool:
        """Remove um servidor MCP."""
        config = self.load_mcp_config()
        
        if "mcpServers" in config and server_id in config["mcpServers"]:
            del config["mcpServers"][server_id]
            return self.save_mcp_config(config)
        
        return False
    
    def get_mcp_servers(self) -> Dict[str, Any]:
        """Obtém todos os servidores MCP configurados."""
        config = self.load_mcp_config()
        return config.get("mcpServers", {})
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Retorna a configuração padrão."""
        return {
            "llm": {
                "model": "gpt-4o",
                "base_url": "https://api.openai.com/v1",
                "api_key": "",
                "max_tokens": 4096,
                "temperature": 0.0
            },
            "browser": {
                "headless": False,
                "disable_security": True,
                "extra_chromium_args": []
            },
            "search": {
                "engine": "Google"
            },
            "sandbox": {
                "use_sandbox": True,
                "image": "python:3.12-slim",
                "work_dir": "/workspace",
                "memory_limit": "512m",
                "cpu_limit": 1.0,
                "timeout": 300
            }
        }
    
    def _get_default_mcp_config(self) -> Dict[str, Any]:
        """Retorna a configuração MCP padrão."""
        return {
            "mcpServers": {}
        }
    
    def export_config(self) -> Dict[str, Any]:
        """Exporta toda a configuração para backup."""
        return {
            "config": self.load_config(),
            "mcp": self.load_mcp_config()
        }
    
    def import_config(self, data: Dict[str, Any]) -> bool:
        """Importa configuração de um backup."""
        try:
            if "config" in data:
                self.save_config(data["config"])
            if "mcp" in data:
                self.save_mcp_config(data["mcp"])
            return True
        except Exception as e:
            print(f"Erro ao importar configuração: {e}")
            return False
    
    def reset_to_defaults(self) -> bool:
        """Restaura as configurações padrão."""
        try:
            self.save_config(self._get_default_config())
            self.save_mcp_config(self._get_default_mcp_config())
            return True
        except Exception as e:
            print(f"Erro ao restaurar padrões: {e}")
            return False
    
    def invalidate_cache(self):
        """Invalida o cache de configuração."""
        self._config_cache = None
        self._mcp_cache = None


# Singleton instance
config_manager = ConfigManager()
