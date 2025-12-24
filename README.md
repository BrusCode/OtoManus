# 🤖 OtoManus - Agente de IA de Propósito Geral com Interface Web

<p align="center">
  <img src="assets/logo.jpg" width="200"/>
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?logo=docker&logoColor=white)](https://www.docker.com/)

**OtoManus** é um fork aprimorado do [OpenManus](https://github.com/FoundationAgents/OpenManus), equipado com uma **interface web completa**, arquitetura de microsserviços containerizada com Docker Compose, e um conjunto de scripts para facilitar a instalação, deploy e gerenciamento.

O objetivo é fornecer uma plataforma robusta e amigável para interagir com um agente de IA de propósito geral, similar ao Manus AI, diretamente pelo navegador.

---

## 📋 Índice

- [Funcionalidades](#-funcionalidades)
- [Arquitetura](#-arquitetura)
- [Instalação Rápida](#-instalação-rápida)
- [Instalação Detalhada](#-instalação-detalhada)
- [Uso da Interface Web](#-uso-da-interface-web)
- [Configuração](#-configuração)
- [Scripts de Gerenciamento](#-scripts-de-gerenciamento)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Ferramentas Disponíveis](#-ferramentas-disponíveis)
- [Contribuição](#-contribuição)
- [Licença](#-licença)

---

## ✨ Funcionalidades

| Funcionalidade | Descrição |
|----------------|-----------|
| **Interface Web Completa** | Chat interativo, gerenciador de arquivos, painel de ferramentas e configurações |
| **Gerenciamento de LLM** | Configure modelos OpenAI, Anthropic, Ollama e outros diretamente pela interface |
| **Suporte a MCP** | Adicione servidores MCP para estender as capacidades do agente |
| **Persistência de Sessões** | Todas as conversas são salvas e podem ser retomadas |
| **Docker Ready** | Stack completo com PostgreSQL, Redis e Nginx |
| **Scripts de Deploy** | Instalação, deploy e gerenciamento simplificados |
| **Múltiplas Ferramentas** | Execução Python, automação de browser, busca web, edição de arquivos |

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                     Interface Web (FastAPI)                  │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────┐ │
│  │  Chat   │ │Arquivos │ │  Tools  │ │   MCP   │ │ Config │ │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └───┬────┘ │
└───────┼──────────┼──────────┼──────────┼─────────────┼──────┘
        │          │          │          │             │
        ▼          ▼          ▼          ▼             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Backend FastAPI (API REST)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │ Session Mgr  │  │ Config Mgr   │  │   Agent Runner   │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Agente OtoManus (ReAct)                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Manus Agent → ToolCall Agent → ReAct Agent → Base   │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌───────┐  │
│  │ Python  │ │ Browser │ │  Search │ │  Editor │ │  MCP  │  │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └───────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Infraestrutura Docker                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐   │
│  │  PostgreSQL  │  │    Redis     │  │      Nginx       │   │
│  └──────────────┘  └──────────────┘  └──────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Instalação Rápida

### Usando o Script de Download (Recomendado)

```bash
# Baixar e executar o script de instalação
curl -fsSL https://raw.githubusercontent.com/BrusCode/OtoManus/main/scripts/quick-install.sh | bash
```

### Usando Git

```bash
# Clonar o repositório
git clone https://github.com/BrusCode/OtoManus.git
cd OtoManus

# Executar instalação
chmod +x scripts/install.sh
./scripts/install.sh
```

---

## 📦 Instalação Detalhada

### Pré-requisitos

- **Python 3.11+**
- **Docker e Docker Compose** (para instalação containerizada)
- **Git**

### Método 1: Docker Compose (Recomendado para Produção)

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/BrusCode/OtoManus.git
   cd OtoManus
   ```

2. **Configure as variáveis de ambiente:**
   ```bash
   cp .env.example .env
   nano .env  # Edite e adicione sua OPENAI_API_KEY
   ```

3. **Inicie os serviços:**
   ```bash
   docker compose up -d
   ```

4. **Acesse a interface:**
   Abra `http://localhost:8000` no navegador.

### Método 2: Instalação Local (Desenvolvimento)

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/BrusCode/OtoManus.git
   cd OtoManus
   ```

2. **Crie um ambiente virtual:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # Linux/Mac
   # ou: venv\Scripts\activate  # Windows
   ```

3. **Instale as dependências:**
   ```bash
   pip install -r requirements.txt
   playwright install chromium
   ```

4. **Configure:**
   ```bash
   cp config/config.example.toml config/config.toml
   nano config/config.toml  # Adicione sua API key
   ```

5. **Inicie o servidor:**
   ```bash
   python web_run.py
   ```

---

## 🖥️ Uso da Interface Web

### Tela de Chat
A tela principal onde você interage com o agente. Digite sua solicitação e o agente irá:
- Analisar a tarefa
- Selecionar as ferramentas apropriadas
- Executar as ações necessárias
- Retornar o resultado

### Gerenciador de Arquivos
Visualize e gerencie os arquivos criados pelo agente no workspace.

### Painel de Ferramentas
Ative ou desative as ferramentas disponíveis:
- `python_execute` - Execução de código Python
- `browser_use` - Automação de navegador
- `web_search` - Busca na web
- `str_replace_editor` - Edição de arquivos
- `ask_human` - Solicitar ajuda do usuário
- `terminate` - Finalizar execução

### Configurações
Configure diretamente pela interface:
- **Modelo LLM**: GPT-4o, Claude, Llama, etc.
- **API Keys**: OpenAI, Anthropic
- **Browser**: Modo headless, segurança
- **Busca**: Motor de busca padrão

### Servidores MCP
Adicione servidores MCP para estender funcionalidades:
- Tipo SSE (Server-Sent Events)
- Tipo STDIO

---

## ⚙️ Configuração

### Arquivo `.env`

```env
# API Keys
OPENAI_API_KEY=sk-sua-chave-aqui
ANTHROPIC_API_KEY=

# Database
POSTGRES_USER=otomanus
POSTGRES_PASSWORD=sua-senha-segura
POSTGRES_DB=otomanus

# Redis
REDIS_PORT=6379

# Application
APP_PORT=8000
DEBUG=false
```

### Arquivo `config/config.toml`

```toml
[llm]
model = "gpt-4o"
base_url = "https://api.openai.com/v1"
api_key = "sk-..."
max_tokens = 4096
temperature = 0.0

[browser]
headless = false
disable_security = true

[search]
engine = "Google"
```

---

## 📜 Scripts de Gerenciamento

### `scripts/install.sh`
Instalação interativa do projeto.
```bash
./scripts/install.sh
```

### `scripts/deploy.sh`
Deploy para produção.
```bash
./scripts/deploy.sh production
```

### `scripts/manage.sh`
Gerenciamento de serviços.
```bash
./scripts/manage.sh start    # Iniciar serviços
./scripts/manage.sh stop     # Parar serviços
./scripts/manage.sh restart  # Reiniciar
./scripts/manage.sh status   # Ver status
./scripts/manage.sh logs     # Ver logs
./scripts/manage.sh backup   # Criar backup
./scripts/manage.sh restore  # Restaurar backup
./scripts/manage.sh db       # Acessar banco de dados
```

### `scripts/quick-install.sh`
Download e instalação em um comando.
```bash
curl -fsSL https://raw.githubusercontent.com/BrusCode/OtoManus/main/scripts/quick-install.sh | bash
```

---

## 📁 Estrutura do Projeto

```
OtoManus/
├── app/
│   ├── agent/           # Agentes (Manus, ToolCall, ReAct, Base)
│   ├── tool/            # Ferramentas (Python, Browser, Search, Editor)
│   ├── prompt/          # Prompts do sistema
│   ├── web/             # Interface web FastAPI
│   │   ├── app.py       # Aplicação principal
│   │   ├── config_manager.py
│   │   ├── session_manager.py
│   │   ├── templates/   # Templates HTML
│   │   └── static/      # CSS e JavaScript
│   ├── config.py        # Configurações
│   ├── llm.py           # Handler LLM
│   └── schema.py        # Schemas Pydantic
├── config/
│   ├── config.example.toml
│   └── mcp.example.json
├── docker/
│   ├── postgres/init.sql
│   └── nginx/nginx.conf
├── scripts/
│   ├── install.sh
│   ├── deploy.sh
│   ├── manage.sh
│   └── quick-install.sh
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
├── web_run.py           # Iniciar interface web
└── main.py              # Iniciar CLI
```

---

## 🔧 Ferramentas Disponíveis

| Ferramenta | Descrição | Categoria |
|------------|-----------|-----------|
| `python_execute` | Executa código Python em ambiente isolado | Execução |
| `browser_use` | Automação de navegador web com Playwright | Browser |
| `web_search` | Busca na web (Google, DuckDuckGo, Bing) | Busca |
| `str_replace_editor` | Criação e edição de arquivos | Arquivos |
| `ask_human` | Solicita informação ao usuário | Interação |
| `terminate` | Finaliza a execução da tarefa | Controle |

---

## 🤝 Contribuição

Contribuições são bem-vindas! Para contribuir:

1. Faça um fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -m 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

---

## 📄 Licença

Este projeto é licenciado sob a [Licença MIT](LICENSE).

---

## 🙏 Agradecimentos

- [OpenManus](https://github.com/FoundationAgents/OpenManus) - Projeto base
- [MetaGPT](https://github.com/geekan/MetaGPT) - Inspiração e suporte
- [browser-use](https://github.com/browser-use/browser-use) - Automação de browser
- [FastAPI](https://fastapi.tiangolo.com/) - Framework web

---

<p align="center">
  Feito com ❤️ pela comunidade
</p>
