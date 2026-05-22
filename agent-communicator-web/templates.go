package main

// HTML template for the Warp-skinned Web Communicator TUI alternative
const indexHTML = `
<!DOCTYPE html>
<html>
<head>
    <title>Agent Communicator Web</title>
    <meta charset="UTF-8">
    <link href="https://fonts.googleapis.com/css2?family=DM+Mono&family=Inter:wght@400;500;600&family=Instrument+Serif:ital@1&display=swap" rel="stylesheet">
    <style>
        :root {
            --color-primary: #f7f5f0;
            --color-canvas: #2b2622;
            --color-canvas-soft: #383330;
            --color-hairline: #3f3a36;
            --color-ink: #f7f5f0;
            --color-body-strong: #dad2c1;
            --color-body: #c9c0ad;
            --color-mute: #aea69c;
            --color-accent: #ff758f;
            --color-active: #00f5d4;
        }
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        body, html {
            width: 100%;
            height: 100%;
            background-color: var(--color-canvas);
            color: var(--color-body);
            font-family: 'Inter', sans-serif;
            overflow: hidden;
            display: flex;
        }
        #sidebar {
            width: 320px;
            background-color: var(--color-canvas-soft);
            border-right: 1px solid var(--color-hairline);
            display: flex;
            flex-direction: column;
            height: 100%;
        }
        #sidebar-header {
            padding: 20px;
            border-bottom: 1px solid var(--color-hairline);
        }
        #sidebar-header h2 {
            font-size: 1.1rem;
            font-weight: 500;
            color: var(--color-primary);
            letter-spacing: -0.5px;
        }
        #agent-list-container {
            flex-grow: 1;
            overflow-y: auto;
            padding: 15px 10px;
        }
        .agent-item {
            padding: 10px 12px;
            border-radius: 3px;
            cursor: pointer;
            margin-bottom: 6px;
            display: flex;
            flex-direction: column;
            gap: 4px;
            border: 1px solid transparent;
            transition: all 0.15s ease;
        }
        .agent-item:hover {
            background-color: var(--color-canvas);
            border-color: var(--color-hairline);
        }
        .agent-item.active {
            background-color: rgba(247, 245, 240, 0.1);
            border-color: var(--color-hairline);
        }
        .agent-meta {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .agent-name {
            font-weight: 600;
            color: var(--color-primary);
            font-size: 0.9rem;
        }
        .agent-status {
            font-size: 0.75rem;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'DM Mono', monospace;
            background-color: var(--color-canvas);
            color: var(--color-mute);
        }
        .agent-status.status-working {
            color: var(--color-active);
            background-color: rgba(0, 245, 212, 0.1);
        }
        .agent-status.status-idle {
            color: var(--color-body);
        }
        .agent-id {
            font-family: 'DM Mono', monospace;
            font-size: 0.75rem;
            color: var(--color-mute);
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
        }

        #chat-panel {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            height: 100%;
            position: relative;
        }
        #chat-header {
            padding: 20px;
            border-bottom: 1px solid var(--color-hairline);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        #chat-header-info h3 {
            color: var(--color-primary);
            font-size: 1.1rem;
            font-weight: 500;
        }
        #chat-header-info p {
            font-size: 0.8rem;
            color: var(--color-mute);
            font-family: 'DM Mono', monospace;
            margin-top: 4px;
        }
        #messages-container {
            flex-grow: 1;
            overflow-y: auto;
            padding: 25px;
            display: flex;
            flex-direction: column;
            gap: 15px;
        }
        .message-bubble {
            max-width: 70%;
            padding: 14px 18px;
            border-radius: 6px;
            line-height: 1.5;
            font-size: 0.95rem;
            border: 1px solid var(--color-hairline);
            display: flex;
            flex-direction: column;
            gap: 6px;
        }
        .message-bubble.incoming {
            align-self: flex-start;
            background-color: var(--color-canvas-soft);
            color: var(--color-body-strong);
        }
        .message-bubble.outgoing {
            align-self: flex-end;
            background-color: var(--color-primary);
            color: var(--color-canvas);
            border-color: var(--color-primary);
        }
        .msg-header {
            display: flex;
            justify-content: space-between;
            font-size: 0.75rem;
            font-family: 'DM Mono', monospace;
        }
        .incoming .msg-header { color: var(--color-mute); }
        .outgoing .msg-header { color: rgba(43, 38, 34, 0.7); }
        
        .msg-body {
            word-break: break-word;
            white-space: pre-wrap;
        }

        #input-area {
            padding: 25px;
            border-top: 1px solid var(--color-hairline);
            display: flex;
            gap: 15px;
            background-color: var(--color-canvas);
        }
        #message-input {
            flex-grow: 1;
            background-color: var(--color-canvas-soft);
            border: 1px solid var(--color-hairline);
            border-radius: 4px;
            color: var(--color-primary);
            padding: 15px;
            font-family: 'Inter', sans-serif;
            font-size: 0.95rem;
            outline: none;
            resize: none;
            height: 54px;
        }
        #message-input:focus {
            border-color: var(--color-mute);
        }
        #send-btn {
            background-color: var(--color-primary);
            color: var(--color-canvas);
            border: none;
            border-radius: 4px;
            padding: 0 25px;
            font-weight: 600;
            font-size: 0.95rem;
            cursor: pointer;
            transition: opacity 0.15s ease;
        }
        #send-btn:hover {
            opacity: 0.9;
        }
        #send-btn:disabled {
            background-color: var(--color-canvas-soft);
            color: var(--color-mute);
            cursor: not-allowed;
        }

        .welcome-screen {
            flex-grow: 1;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
            color: var(--color-mute);
            gap: 10px;
        }
        .welcome-screen h2 {
            color: var(--color-primary);
            font-weight: 400;
            letter-spacing: -0.5px;
        }
    </style>
</head>
<body>
    <div id="sidebar">
        <div id="sidebar-header">
            <h2>Local Agents</h2>
        </div>
        <div id="agent-list-container">
            <p style="color: var(--color-mute); font-size: 0.85rem; padding: 10px;">Loading agents...</p>
        </div>
    </div>

    <div id="chat-panel">
        <div class="welcome-screen" id="welcome-screen">
            <h2>Warp Communicator Panel</h2>
            <p>Select an active agent from the sidebar to initiate direct communication.</p>
        </div>

        <div id="chat-area" style="display: none; flex-direction: column; height: 100%;">
            <div id="chat-header">
                <div id="chat-header-info">
                    <h3 id="active-agent-title">agent-name</h3>
                    <p id="active-agent-desc">ID: 0000-0000</p>
                </div>
            </div>
            <div id="messages-container">
                <!-- Chat message bubbles -->
            </div>
            <div id="input-area">
                <textarea id="message-input" placeholder="Type message... (Press Enter to send, Shift+Enter for newline)"></textarea>
                <button id="send-btn" onclick="submitMessage()">Send</button>
            </div>
        </div>
    </div>

    <script>
        let activeAgentName = "";
        let activeAgentId = "";
        let activeAgentAddress = "";
        let myAgentName = "web-builder-agent"; // Unified sender identity
        let messageCache = {};

        // Fetch local agents on startup
        async function loadAgents() {
            try {
                const response = await fetch('/api/agents');
                if (!response.ok) throw new Error('Failed to fetch agents');
                const agentsMap = await response.json();
                
                const container = document.getElementById('agent-list-container');
                container.innerHTML = "";
                
                let found = false;
                for (const key in agentsMap) {
                    const agent = agentsMap[key];
                    // Skip listing ourselves as a recipient
                    if (agent.name === myAgentName) continue;
                    found = true;

                    const isWorking = agent.status.toLowerCase() === 'working';
                    const statusClass = isWorking ? 'status-working' : 'status-idle';
                    
                    const item = document.createElement('div');
                    item.className = 'agent-item ' + (activeAgentName === agent.name ? 'active' : '');
                    item.onclick = () => selectAgent(agent.name, agent.agent_id, agent.target_address || agent.name);
                    
                    item.innerHTML = 
                        '<div class="agent-meta">' +
                            '<span class="agent-name">' + agent.name + '</span>' +
                            '<span class="agent-status ' + statusClass + '">' + agent.status + '</span>' +
                        '</div>' +
                        '<span class="agent-id">ID: ' + agent.agent_id + '</span>';
                    
                    container.appendChild(item);
                }
                
                if (!found) {
                    container.innerHTML = '<p style="color: var(--color-mute); font-size: 0.85rem; padding: 10px;">No other active agents found.</p>';
                }
            } catch (e) {
                console.error(e);
            }
        }

        // Select target agent to view chat
        function selectAgent(name, id, address) {
            activeAgentName = name;
            activeAgentId = id;
            activeAgentAddress = address;
            
            document.getElementById('welcome-screen').style.display = 'none';
            document.getElementById('chat-area').style.display = 'flex';
            
            document.getElementById('active-agent-title').innerText = name;
            document.getElementById('active-agent-desc').innerText = 'Address: ' + address + ' | ID: ' + id;
            
            // Refresh list highlighting
            const items = document.getElementsByClassName('agent-item');
            for (let i = 0; i < items.length; i++) {
                const itemTitle = items[i].querySelector('.agent-name').innerText;
                if (itemTitle === name) {
                    items[i].classList.add('active');
                } else {
                    items[i].classList.remove('active');
                }
            }
            
            loadMessages(name);
        }

        // Fetch target agent's direct inbox message stream
        async function loadMessages(agentName) {
            if (activeAgentName !== agentName) return;
            try {
                const response = await fetch('/api/inbox?agent=' + agentName + '&clear=true');
                if (!response.ok) throw new Error('Failed to fetch inbox');
                const data = await response.json();
                
                if (!messageCache[agentName]) {
                    messageCache[agentName] = [];
                }
                
                // Append any new messages returned
                if (data.messages && data.messages.length > 0) {
                    data.messages.forEach(msg => {
                        // Avoid duplicates
                        if (!messageCache[agentName].some(m => m.timestamp === msg.timestamp && m.sender === msg.sender)) {
                            messageCache[agentName].push(msg);
                        }
                    });
                }
                
                renderMessages(agentName);
            } catch (e) {
                console.error(e);
            }
        }

        // Render chronological message array
        function renderMessages(agentName) {
            const container = document.getElementById('messages-container');
            container.innerHTML = "";
            
            const list = messageCache[agentName] || [];
            
            // Sort messages chronologically by timestamp
            list.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
            
            if (list.length === 0) {
                container.innerHTML = '<div style="text-align: center; color: var(--color-mute); font-size: 0.9rem; margin-top: 40px;">No messages in history.</div>';
                return;
            }
            
            list.forEach(msg => {
                const bubble = document.createElement('div');
                const isOutgoing = msg.sender === myAgentName;
                bubble.className = 'message-bubble ' + (isOutgoing ? 'outgoing' : 'incoming');
                
                const timeStr = new Date(msg.timestamp).toLocaleTimeString();
                
                bubble.innerHTML = 
                    '<div class="msg-header">' +
                        '<span>' + (isOutgoing ? 'You' : msg.sender) + '</span>' +
                        '<span>' + timeStr + '</span>' +
                    '</div>' +
                    '<div class="msg-body">' + escapeHTML(msg.message) + '</div>';
                
                container.appendChild(bubble);
            });
            
            // Auto scroll to the bottom of the container
            container.scrollTop = container.scrollHeight;
        }

        // Submit message handler
        async function submitMessage() {
            const input = document.getElementById('message-input');
            const body = input.value.trim();
            if (!body || !activeAgentName) return;
            
            const sendBtn = document.getElementById('send-btn');
            sendBtn.disabled = true;
            
            try {
                const payload = {
                    sender: myAgentName,
                    target: activeAgentAddress,
                    message: body
                };
                
                const response = await fetch('/api/send', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                
                if (!response.ok) {
                    const text = await response.text();
                    throw new Error(text || 'Failed to send message');
                }
                
                // Add directly to local outgoing message cache
                if (!messageCache[activeAgentName]) {
                    messageCache[activeAgentName] = [];
                }
                
                messageCache[activeAgentName].push({
                    sender: myAgentName,
                    timestamp: new Date().toISOString(),
                    message: body,
                    read: true
                });
                
                input.value = "";
                renderMessages(activeAgentName);
            } catch (e) {
                alert("Error sending message: " + e.message);
            } finally {
                sendBtn.disabled = false;
            }
        }

        // Listen for key presses inside text input area
        document.getElementById('message-input').addEventListener('keydown', function(e) {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                submitMessage();
            }
        });

        // Initialize Server-Sent Events (SSE) push notifications listener
        function setupSSE() {
            const source = new EventSource('/api/events');
            
            source.onmessage = function(event) {
                try {
                    const ev = JSON.parse(event.data);
                    console.log("SSE Event received:", ev);
                    
                    // Handle new direct message events
                    if (ev.type === 'message_received' || ev.type === 'inbox_appended') {
                        if (activeAgentName && ev.sender === activeAgentName) {
                            loadMessages(activeAgentName);
                        } else if (ev.sender) {
                            loadMessages(ev.sender);
                        }
                    }
                    
                    // Trigger active agent list reload on agent updates/registry events
                    if (ev.type === 'agent_registered' || ev.type === 'agent_status_changed' || ev.type === 'heartbeat') {
                        loadAgents();
                    }
                } catch (e) {
                    console.error("Failed to parse SSE payload:", e);
                }
            };
            
            source.onerror = function(err) {
                console.error("SSE Connection dropped, reconnecting...", err);
            };
        }

        // Helpers
        function escapeHTML(str) {
            return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
        }

        // Startup routine
        window.onload = () => {
            loadAgents();
            setupSSE();
            setInterval(loadAgents, 15000);
        };
    </script>
</body>
</html>
`
