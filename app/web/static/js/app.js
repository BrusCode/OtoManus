/**
 * Otomanus Web Interface - JavaScript Application
 */

class OtomanusApp {
    constructor() {
        this.sessionId = null;
        this.websocket = null;
        this.currentView = 'chat';
        
        this.init();
    }
    
    init() {
        this.bindNavigation();
        this.bindChatEvents();
        this.bindFileEvents();
        this.bindToolEvents();
        this.bindMCPEvents();
        this.bindConfigEvents();
        this.bindLogEvents();
        
        // Load initial data
        this.loadConfig();
        this.loadTools();
        this.loadMCPServers();
        
        // Create initial session
        this.createSession();
    }
    
    // Navigation
    bindNavigation() {
        document.querySelectorAll('.nav-item').forEach(item => {
            item.addEventListener('click', (e) => {
                const view = e.currentTarget.dataset.view;
                this.switchView(view);
            });
        });
    }
    
    switchView(viewName) {
        // Update nav items
        document.querySelectorAll('.nav-item').forEach(item => {
            item.classList.toggle('active', item.dataset.view === viewName);
        });
        
        // Update views
        document.querySelectorAll('.view').forEach(view => {
            view.classList.toggle('active', view.id === `${viewName}-view`);
        });
        
        this.currentView = viewName;
        
        // Load view-specific data
        switch (viewName) {
            case 'files':
                this.loadFiles();
                break;
            case 'logs':
                this.loadLogs();
                break;
        }
    }
    
    // Session Management
    async createSession() {
        try {
            const response = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ prompt: '' })
            });
            
            if (response.ok) {
                const data = await response.json();
                this.sessionId = data.session_id;
                this.connectWebSocket();
            }
        } catch (error) {
            console.error('Failed to create session:', error);
        }
    }
    
    connectWebSocket() {
        if (!this.sessionId) return;
        
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws/${this.sessionId}`;
        
        this.websocket = new WebSocket(wsUrl);
        
        this.websocket.onopen = () => {
            this.updateConnectionStatus(true);
        };
        
        this.websocket.onclose = () => {
            this.updateConnectionStatus(false);
            // Reconnect after 3 seconds
            setTimeout(() => this.connectWebSocket(), 3000);
        };
        
        this.websocket.onmessage = (event) => {
            const data = JSON.parse(event.data);
            this.handleWebSocketMessage(data);
        };
        
        this.websocket.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }
    
    updateConnectionStatus(connected) {
        const statusText = document.getElementById('connection-status');
        const statusDot = document.querySelector('.status-dot');
        
        if (connected) {
            statusText.textContent = 'Conectado';
            statusDot.classList.remove('disconnected');
        } else {
            statusText.textContent = 'Desconectado';
            statusDot.classList.add('disconnected');
        }
    }
    
    handleWebSocketMessage(data) {
        switch (data.type) {
            case 'status':
                this.showThinkingStep(data.message);
                break;
            case 'thinking':
                this.showThinkingStep(data.step);
                break;
            case 'complete':
                this.addMessage('assistant', data.result);
                this.hideThinking();
                this.enableInput();
                break;
            case 'error':
                this.addMessage('error', data.message);
                this.hideThinking();
                this.enableInput();
                break;
            case 'pong':
                // Heartbeat response
                break;
        }
    }
    
    // Chat Events
    bindChatEvents() {
        const input = document.getElementById('chat-input');
        const sendBtn = document.getElementById('send-btn');
        const newChatBtn = document.getElementById('new-chat-btn');
        
        // Auto-resize textarea
        input.addEventListener('input', () => {
            input.style.height = 'auto';
            input.style.height = Math.min(input.scrollHeight, 150) + 'px';
            sendBtn.disabled = !input.value.trim();
        });
        
        // Send on Enter (Shift+Enter for new line)
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                if (input.value.trim()) {
                    this.sendMessage(input.value);
                }
            }
        });
        
        // Send button click
        sendBtn.addEventListener('click', () => {
            if (input.value.trim()) {
                this.sendMessage(input.value);
            }
        });
        
        // New chat button
        newChatBtn.addEventListener('click', () => {
            this.startNewChat();
        });
        
        // Suggestion buttons
        document.querySelectorAll('.suggestion-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const prompt = btn.dataset.prompt;
                input.value = prompt;
                input.dispatchEvent(new Event('input'));
            });
        });
        
        // Thinking panel toggle
        const thinkingToggle = document.getElementById('thinking-toggle');
        thinkingToggle.addEventListener('click', () => {
            const content = document.getElementById('thinking-content');
            content.classList.toggle('collapsed');
            thinkingToggle.classList.toggle('collapsed');
        });
    }
    
    async sendMessage(content) {
        // Add user message to chat
        this.addMessage('user', content);
        
        // Clear input
        const input = document.getElementById('chat-input');
        input.value = '';
        input.style.height = 'auto';
        document.getElementById('send-btn').disabled = true;
        
        // Hide welcome message
        const welcome = document.querySelector('.welcome-message');
        if (welcome) {
            welcome.style.display = 'none';
        }
        
        // Show thinking panel
        this.showThinking();
        this.disableInput();
        
        try {
            const response = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    prompt: content,
                    session_id: this.sessionId
                })
            });
            
            if (!response.ok) {
                throw new Error('Failed to send message');
            }
        } catch (error) {
            console.error('Error sending message:', error);
            this.addMessage('error', 'Erro ao enviar mensagem. Tente novamente.');
            this.hideThinking();
            this.enableInput();
        }
    }
    
    addMessage(role, content) {
        const messagesContainer = document.getElementById('chat-messages');
        
        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${role}`;
        
        const avatar = document.createElement('div');
        avatar.className = 'message-avatar';
        
        if (role === 'user') {
            avatar.innerHTML = `
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                    <circle cx="12" cy="7" r="4"/>
                </svg>
            `;
        } else {
            avatar.innerHTML = `
                <svg width="20" height="20" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="16" cy="16" r="14" stroke="currentColor" stroke-width="2"/>
                    <circle cx="16" cy="16" r="6" fill="currentColor"/>
                </svg>
            `;
        }
        
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        contentDiv.innerHTML = `<p>${this.formatMessage(content)}</p>`;
        
        messageDiv.appendChild(avatar);
        messageDiv.appendChild(contentDiv);
        
        messagesContainer.appendChild(messageDiv);
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }
    
    formatMessage(content) {
        // Basic markdown-like formatting
        return content
            .replace(/```(\w*)\n([\s\S]*?)```/g, '<pre><code class="language-$1">$2</code></pre>')
            .replace(/`([^`]+)`/g, '<code>$1</code>')
            .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
            .replace(/\n/g, '<br>');
    }
    
    showThinking() {
        const panel = document.getElementById('thinking-panel');
        const content = document.getElementById('thinking-content');
        panel.classList.add('active');
        content.innerHTML = '';
    }
    
    hideThinking() {
        const panel = document.getElementById('thinking-panel');
        panel.classList.remove('active');
    }
    
    showThinkingStep(step) {
        const content = document.getElementById('thinking-content');
        const stepDiv = document.createElement('div');
        stepDiv.className = 'thinking-step';
        stepDiv.innerHTML = `
            <span class="thinking-step-icon">→</span>
            <span>${step}</span>
        `;
        content.appendChild(stepDiv);
        content.scrollTop = content.scrollHeight;
    }
    
    disableInput() {
        document.getElementById('chat-input').disabled = true;
        document.getElementById('send-btn').disabled = true;
    }
    
    enableInput() {
        document.getElementById('chat-input').disabled = false;
        const input = document.getElementById('chat-input');
        document.getElementById('send-btn').disabled = !input.value.trim();
    }
    
    startNewChat() {
        // Clear messages
        const messagesContainer = document.getElementById('chat-messages');
        messagesContainer.innerHTML = `
            <div class="welcome-message">
                <div class="welcome-icon">
                    <svg width="48" height="48" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
                        <circle cx="16" cy="16" r="14" stroke="currentColor" stroke-width="2"/>
                        <circle cx="16" cy="16" r="6" fill="currentColor"/>
                    </svg>
                </div>
                <h2>Bem-vindo ao Otomanus</h2>
                <p>Sou um assistente de IA capaz de executar diversas tarefas. Como posso ajudá-lo hoje?</p>
                <div class="suggestions">
                    <button class="suggestion-btn" data-prompt="Crie um script Python que analise dados de um arquivo CSV">
                        Analisar dados CSV
                    </button>
                    <button class="suggestion-btn" data-prompt="Pesquise na web sobre as últimas tendências em IA">
                        Pesquisar na web
                    </button>
                    <button class="suggestion-btn" data-prompt="Crie uma página HTML simples com um formulário de contato">
                        Criar página web
                    </button>
                </div>
            </div>
        `;
        
        // Re-bind suggestion buttons
        document.querySelectorAll('.suggestion-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const prompt = btn.dataset.prompt;
                document.getElementById('chat-input').value = prompt;
                document.getElementById('chat-input').dispatchEvent(new Event('input'));
            });
        });
        
        // Create new session
        this.createSession();
    }
    
    // Files Events
    bindFileEvents() {
        document.getElementById('refresh-files-btn').addEventListener('click', () => {
            this.loadFiles();
        });
    }
    
    async loadFiles() {
        const filesList = document.getElementById('files-list');
        filesList.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
        
        try {
            const response = await fetch('/api/files');
            const data = await response.json();
            
            if (data.files.length === 0) {
                filesList.innerHTML = '<div class="mcp-empty">Nenhum arquivo no workspace</div>';
                return;
            }
            
            filesList.innerHTML = data.files.map(file => `
                <div class="file-item" data-path="${file.path}">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                        <polyline points="14 2 14 8 20 8"/>
                    </svg>
                    <div class="file-info">
                        <div class="file-name">${file.name}</div>
                        <div class="file-meta">${this.formatFileSize(file.size)}</div>
                    </div>
                </div>
            `).join('');
            
            // Bind click events
            filesList.querySelectorAll('.file-item').forEach(item => {
                item.addEventListener('click', () => {
                    filesList.querySelectorAll('.file-item').forEach(i => i.classList.remove('active'));
                    item.classList.add('active');
                    this.loadFileContent(item.dataset.path);
                });
            });
        } catch (error) {
            console.error('Error loading files:', error);
            filesList.innerHTML = '<div class="mcp-empty">Erro ao carregar arquivos</div>';
        }
    }
    
    async loadFileContent(path) {
        const preview = document.getElementById('file-preview');
        preview.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
        
        try {
            const response = await fetch(`/api/files/${encodeURIComponent(path)}`);
            const data = await response.json();
            
            preview.innerHTML = `
                <div class="file-preview-content">
                    <pre>${this.escapeHtml(data.content)}</pre>
                </div>
            `;
        } catch (error) {
            console.error('Error loading file content:', error);
            preview.innerHTML = '<div class="file-preview-placeholder"><p>Erro ao carregar arquivo</p></div>';
        }
    }
    
    formatFileSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    // Tools Events
    bindToolEvents() {
        // Tools are loaded on init
    }
    
    async loadTools() {
        const toolsList = document.getElementById('tools-list');
        
        try {
            const response = await fetch('/api/tools');
            const data = await response.json();
            
            toolsList.innerHTML = data.tools.map(tool => `
                <div class="tool-card">
                    <div class="tool-header">
                        <span class="tool-name">${tool.name}</span>
                        <label class="tool-toggle">
                            <input type="checkbox" ${tool.enabled ? 'checked' : ''} data-tool="${tool.name}">
                            <span class="tool-toggle-slider"></span>
                        </label>
                    </div>
                    <p class="tool-description">${tool.description}</p>
                    <span class="tool-category">${tool.category}</span>
                </div>
            `).join('');
            
            // Bind toggle events
            toolsList.querySelectorAll('.tool-toggle input').forEach(toggle => {
                toggle.addEventListener('change', async (e) => {
                    const toolName = e.target.dataset.tool;
                    const enabled = e.target.checked;
                    await this.toggleTool(toolName, enabled);
                });
            });
        } catch (error) {
            console.error('Error loading tools:', error);
            toolsList.innerHTML = '<div class="mcp-empty">Erro ao carregar ferramentas</div>';
        }
    }
    
    async toggleTool(toolName, enabled) {
        try {
            await fetch(`/api/tools/${toolName}/toggle?enabled=${enabled}`, {
                method: 'POST'
            });
        } catch (error) {
            console.error('Error toggling tool:', error);
        }
    }
    
    // MCP Events
    bindMCPEvents() {
        const addBtn = document.getElementById('add-mcp-btn');
        const modal = document.getElementById('mcp-modal');
        const closeBtn = document.getElementById('mcp-modal-close');
        const cancelBtn = document.getElementById('mcp-cancel');
        const form = document.getElementById('mcp-form');
        const typeSelect = document.getElementById('mcp-type');
        
        addBtn.addEventListener('click', () => {
            modal.classList.add('active');
        });
        
        closeBtn.addEventListener('click', () => {
            modal.classList.remove('active');
        });
        
        cancelBtn.addEventListener('click', () => {
            modal.classList.remove('active');
        });
        
        // Toggle fields based on type
        typeSelect.addEventListener('change', () => {
            const isSSE = typeSelect.value === 'sse';
            document.getElementById('mcp-url-group').classList.toggle('hidden', !isSSE);
            document.getElementById('mcp-command-group').classList.toggle('hidden', isSSE);
            document.getElementById('mcp-args-group').classList.toggle('hidden', isSSE);
        });
        
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.addMCPServer();
            modal.classList.remove('active');
            form.reset();
        });
    }
    
    async loadMCPServers() {
        const serversList = document.getElementById('mcp-servers-list');
        
        try {
            const response = await fetch('/api/mcp/servers');
            const data = await response.json();
            
            if (data.servers.length === 0) {
                serversList.innerHTML = `
                    <div class="mcp-empty">
                        <p>Nenhum servidor MCP configurado</p>
                        <p>Clique em "Adicionar Servidor" para começar</p>
                    </div>
                `;
                return;
            }
            
            serversList.innerHTML = data.servers.map(server => `
                <div class="mcp-server-card" data-id="${server.id}">
                    <div class="mcp-server-header">
                        <span class="mcp-server-name">${server.id}</span>
                        <span class="mcp-server-status">
                            <span class="status-dot"></span>
                            Configurado
                        </span>
                    </div>
                    <dl class="mcp-server-details">
                        <dt>Tipo:</dt>
                        <dd>${server.type.toUpperCase()}</dd>
                        ${server.url ? `<dt>URL:</dt><dd>${server.url}</dd>` : ''}
                        ${server.command ? `<dt>Comando:</dt><dd>${server.command}</dd>` : ''}
                        ${server.args ? `<dt>Args:</dt><dd>${server.args.join(', ')}</dd>` : ''}
                    </dl>
                    <div class="mcp-server-actions">
                        <button class="btn btn-secondary btn-remove-mcp" data-id="${server.id}">Remover</button>
                    </div>
                </div>
            `).join('');
            
            // Bind remove buttons
            serversList.querySelectorAll('.btn-remove-mcp').forEach(btn => {
                btn.addEventListener('click', async () => {
                    await this.removeMCPServer(btn.dataset.id);
                });
            });
        } catch (error) {
            console.error('Error loading MCP servers:', error);
            serversList.innerHTML = '<div class="mcp-empty">Erro ao carregar servidores MCP</div>';
        }
    }
    
    async addMCPServer() {
        const serverId = document.getElementById('mcp-server-id').value;
        const type = document.getElementById('mcp-type').value;
        const url = document.getElementById('mcp-url').value;
        const command = document.getElementById('mcp-command').value;
        const args = document.getElementById('mcp-args').value.split(',').map(a => a.trim()).filter(a => a);
        
        try {
            await fetch('/api/mcp/servers', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    server_id: serverId,
                    type,
                    url: type === 'sse' ? url : null,
                    command: type === 'stdio' ? command : null,
                    args: type === 'stdio' ? args : null
                })
            });
            
            this.loadMCPServers();
        } catch (error) {
            console.error('Error adding MCP server:', error);
        }
    }
    
    async removeMCPServer(serverId) {
        if (!confirm(`Remover servidor MCP "${serverId}"?`)) return;
        
        try {
            await fetch(`/api/mcp/servers/${serverId}`, {
                method: 'DELETE'
            });
            
            this.loadMCPServers();
        } catch (error) {
            console.error('Error removing MCP server:', error);
        }
    }
    
    // Config Events
    bindConfigEvents() {
        document.getElementById('save-config-btn').addEventListener('click', () => {
            this.saveConfig();
        });
        
        document.getElementById('reset-config-btn').addEventListener('click', () => {
            this.loadConfig();
        });
    }
    
    async loadConfig() {
        try {
            const response = await fetch('/api/config');
            const data = await response.json();
            
            // LLM config
            if (data.llm) {
                document.getElementById('llm-model').value = data.llm.model || 'gpt-4o';
                document.getElementById('llm-base-url').value = data.llm.base_url || '';
                document.getElementById('llm-max-tokens').value = data.llm.max_tokens || 4096;
                document.getElementById('llm-temperature').value = data.llm.temperature || 0.0;
            }
            
            // Browser config
            if (data.browser) {
                document.getElementById('browser-headless').checked = data.browser.headless || false;
                document.getElementById('browser-disable-security').checked = data.browser.disable_security !== false;
            }
            
            // Search config
            if (data.search) {
                document.getElementById('search-engine').value = data.search.engine || 'Google';
            }
        } catch (error) {
            console.error('Error loading config:', error);
        }
    }
    
    async saveConfig() {
        const config = {
            llm: {
                model: document.getElementById('llm-model').value,
                base_url: document.getElementById('llm-base-url').value,
                api_key: document.getElementById('llm-api-key').value,
                max_tokens: parseInt(document.getElementById('llm-max-tokens').value),
                temperature: parseFloat(document.getElementById('llm-temperature').value)
            },
            browser: {
                headless: document.getElementById('browser-headless').checked,
                disable_security: document.getElementById('browser-disable-security').checked
            },
            search: {
                engine: document.getElementById('search-engine').value
            }
        };
        
        try {
            const response = await fetch('/api/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(config)
            });
            
            const data = await response.json();
            alert(data.message);
        } catch (error) {
            console.error('Error saving config:', error);
            alert('Erro ao salvar configurações');
        }
    }
    
    // Logs Events
    bindLogEvents() {
        document.getElementById('refresh-logs-btn').addEventListener('click', () => {
            this.loadLogs();
        });
    }
    
    async loadLogs() {
        const logsList = document.getElementById('logs-list');
        logsList.innerHTML = '<div class="loading"><div class="spinner"></div></div>';
        
        try {
            const response = await fetch('/api/logs');
            const data = await response.json();
            
            if (data.logs.length === 0) {
                logsList.innerHTML = '<div class="mcp-empty">Nenhum arquivo de log</div>';
                return;
            }
            
            logsList.innerHTML = data.logs.map(log => `
                <div class="log-item" data-name="${log.name}">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                        <polyline points="14 2 14 8 20 8"/>
                    </svg>
                    ${log.name}
                </div>
            `).join('');
            
            // Bind click events
            logsList.querySelectorAll('.log-item').forEach(item => {
                item.addEventListener('click', () => {
                    logsList.querySelectorAll('.log-item').forEach(i => i.classList.remove('active'));
                    item.classList.add('active');
                    this.loadLogContent(item.dataset.name);
                });
            });
        } catch (error) {
            console.error('Error loading logs:', error);
            logsList.innerHTML = '<div class="mcp-empty">Erro ao carregar logs</div>';
        }
    }
    
    async loadLogContent(logName) {
        const logText = document.getElementById('log-text');
        logText.textContent = 'Carregando...';
        
        try {
            const response = await fetch(`/api/logs/${encodeURIComponent(logName)}`);
            const data = await response.json();
            logText.textContent = data.content;
        } catch (error) {
            console.error('Error loading log content:', error);
            logText.textContent = 'Erro ao carregar log';
        }
    }
}

// Initialize app when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    window.app = new OtomanusApp();
});
