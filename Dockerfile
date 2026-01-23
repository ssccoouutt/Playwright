FROM python:3.11-slim

# Install system dependencies for Playwright/Chromium
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libx11-6 libxcb1 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libgbm1 libasound2 \
    libcups2 libxkbcommon0 \
    fonts-liberation fonts-unifont \
    libpangocairo-1.0-0 libpango-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies
RUN pip install playwright==1.40.0 fastapi==0.104.1 uvicorn==0.24.0 python-multipart jinja2 requests psutil

# Install Chromium
RUN playwright install chromium

# Create directories
RUN mkdir -p templates screenshots static

# --- HTML TEMPLATE (Enhanced for Multiple Automations) ---
RUN cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🤖 Multi-Colab Automation</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root { --primary: #6366f1; --bg: #f8fafc; --card: #ffffff; --text: #1e293b; }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }
        body { background: var(--bg); color: var(--text); padding: 15px; }
        .container { max-width: 1200px; margin: 0 auto; }
        
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; background: white; padding: 15px 25px; border-radius: 12px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .header h1 { font-size: 1.5rem; color: var(--primary); display: flex; align-items: center; gap: 10px; }
        
        .grid { display: grid; grid-template-columns: 1fr 350px; gap: 20px; }
        @media (max-width: 900px) { .grid { grid-template-columns: 1fr; } }
        
        .card { background: var(--card); border-radius: 12px; padding: 20px; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); margin-bottom: 20px; }
        .card h2 { font-size: 1.1rem; margin-bottom: 15px; display: flex; align-items: center; gap: 10px; border-bottom: 1px solid #f1f5f9; padding-bottom: 10px; }

        .input-bar { display: flex; gap: 10px; margin-bottom: 20px; }
        input[type="url"] { flex: 1; padding: 12px; border: 1px solid #e2e8f0; border-radius: 8px; outline: none; }
        input[type="url"]:focus { border-color: var(--primary); }

        .task-list { display: flex; flex-direction: column; gap: 10px; }
        .task-item { display: flex; align-items: center; justify-content: space-between; padding: 15px; background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 10px; transition: all 0.2s; }
        .task-item:hover { border-color: var(--primary); }
        .task-info { flex: 1; min-width: 0; }
        .task-url { font-size: 0.85rem; color: #64748b; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .task-status { font-size: 0.75rem; font-weight: bold; margin-top: 4px; display: flex; align-items: center; gap: 5px; }
        .status-running { color: #10b981; }
        .status-stopped { color: #ef4444; }

        .btn { padding: 10px 18px; border-radius: 8px; border: none; cursor: pointer; font-weight: 600; font-size: 0.9rem; display: flex; align-items: center; gap: 8px; transition: 0.2s; }
        .btn-p { background: var(--primary); color: white; }
        .btn-s { background: #f1f5f9; color: #475569; }
        .btn-d { background: #fee2e2; color: #dc2626; }
        .btn:hover { opacity: 0.9; transform: translateY(-1px); }
        .btn:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

        .log-box { background: #0f172a; color: #38bdf8; padding: 15px; border-radius: 10px; height: 250px; overflow-y: auto; font-family: 'Consolas', monospace; font-size: 12px; border: 1px solid #1e293b; }
        .log-entry { margin-bottom: 4px; border-bottom: 1px solid #1e293b; padding-bottom: 2px; }
        .log-time { color: #64748b; }

        .stats { display: flex; flex-direction: column; gap: 12px; }
        .stat-item { display: flex; justify-content: space-between; font-size: 0.9rem; }
        .stat-val { font-weight: bold; font-family: monospace; }
        
        .mem-track { height: 8px; background: #e2e8f0; border-radius: 4px; overflow: hidden; }
        .mem-bar { height: 100%; background: var(--primary); transition: width 0.5s; }

        .screenshot-container { position: relative; width: 100%; border-radius: 8px; overflow: hidden; border: 2px solid #e2e8f0; background: #f1f5f9; min-height: 200px; display: flex; align-items: center; justify-content: center; }
        .screenshot-container img { width: 100%; height: auto; display: block; }
        .loader { position: fixed; top: 0; left: 0; width: 100%; height: 3px; background: var(--primary); animation: loading 2s infinite; display: none; z-index: 1000; }
        @keyframes loading { 0% { left: -100%; width: 30%; } 100% { left: 100%; width: 30%; } }
    </style>
</head>
<body>
    <div id="topLoader" class="loader"></div>
    <div class="container">
        <header class="header">
            <h1><i class="fas fa-robot"></i> Colab Multi-Manager</h1>
            <div id="globalStatus" style="font-size: 0.8rem; color: #64748b;">
                Browser: <span id="bState" style="font-weight: bold;">Initializing...</span>
            </div>
        </header>

        <div class="grid">
            <main>
                <div class="card">
                    <h2><i class="fas fa-plus"></i> New Automation</h2>
                    <div class="input-bar">
                        <input type="url" id="colabUrl" placeholder="https://colab.research.google.com/drive/...">
                        <button class="btn btn-p" onclick="addTask()"><i class="fas fa-plus"></i> Add Tab</button>
                    </div>
                </div>

                <div class="card">
                    <h2><i class="fas fa-layer-group"></i> Active Automations</h2>
                    <div id="taskList" class="task-list">
                        <!-- Tasks inject here -->
                    </div>
                </div>

                <div class="card">
                    <h2><i class="fas fa-camera"></i> Live Preview</h2>
                    <div id="previewBox" class="screenshot-container">
                        <p style="color: #94a3b8;">Select a tab to see live preview</p>
                    </div>
                </div>
            </main>

            <aside>
                <div class="card">
                    <h2><i class="fas fa-microchip"></i> Resource Monitor</h2>
                    <div class="stats">
                        <div class="stat-item"><span>RAM Usage:</span> <span id="memText" class="stat-val">0 / 512 MB</span></div>
                        <div class="mem-track"><div id="memBar" class="mem-bar" style="width: 0%"></div></div>
                        <div class="stat-item"><span>Active Tabs:</span> <span id="tabCount" class="stat-val">0</span></div>
                        <div class="stat-item"><span>Uptime:</span> <span id="uptime" class="stat-val">00:00:00</span></div>
                    </div>
                    <div style="margin-top: 15px; display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
                        <button class="btn btn-s" onclick="refreshCookies()"><i class="fas fa-cookie"></i> Cookies</button>
                        <button class="btn btn-d" onclick="restartBrowser()"><i class="fas fa-redo"></i> Restart</button>
                    </div>
                </div>

                <div class="card">
                    <h2><i class="fas fa-terminal"></i> Activity Logs</h2>
                    <div id="logBox" class="log-box"></div>
                    <button class="btn btn-s" onclick="clearLogs()" style="width: 100%; margin-top: 10px;">Clear Logs</button>
                </div>
            </aside>
        </div>
    </div>

    <script>
        let currentTasks = [];
        let selectedTabIdx = null;

        function addLog(msg, type='info') {
            const logBox = document.getElementById('logBox');
            const time = new Date().toLocaleTimeString();
            const div = document.createElement('div');
            div.className = 'log-entry';
            div.innerHTML = `<span class="log-time">[${time}]</span> <span style="color: ${type==='error'?'#f87171':(type==='success'?'#4ade80':'#38bdf8')}">${msg}</span>`;
            logBox.appendChild(div);
            logBox.scrollTop = logBox.scrollHeight;
        }

        async function api(path, method='GET', body=null) {
            document.getElementById('topLoader').style.display = 'block';
            try {
                const options = { method, headers: {'Content-Type': 'application/json'} };
                if(body) options.body = JSON.stringify(body);
                const res = await fetch(path, options);
                return await res.json();
            } catch(e) {
                addLog('API Error: ' + e.message, 'error');
                return { success: false };
            } finally {
                document.getElementById('topLoader').style.display = 'none';
            }
        }

        async function updateStatus() {
            const data = await api('/status');
            if(!data) return;

            document.getElementById('bState').textContent = data.browser_ready ? 'ONLINE' : 'CRASHED';
            document.getElementById('bState').style.color = data.browser_ready ? '#10b981' : '#ef4444';
            
            document.getElementById('memText').textContent = `${data.memory_usage} / 512 MB`;
            document.getElementById('memBar').style.width = Math.min((data.memory_usage / 512) * 100, 100) + '%';
            document.getElementById('tabCount').textContent = data.tasks.length;

            const list = document.getElementById('taskList');
            list.innerHTML = '';
            currentTasks = data.tasks;

            data.tasks.forEach((task, idx) => {
                const item = document.createElement('div');
                item.className = 'task-item';
                item.innerHTML = `
                    <div class="task-info">
                        <div style="font-weight: bold; font-size: 0.9rem;">Tab #${idx + 1}</div>
                        <div class="task-url">${task.url}</div>
                        <div class="task-status ${task.running ? 'status-running' : 'status-stopped'}">
                            <i class="fas fa-${task.running?'sync fa-spin':'pause'}"></i> ${task.running ? 'Automating' : 'Stopped'}
                        </div>
                    </div>
                    <div style="display: flex; gap: 8px;">
                        <button class="btn btn-s" onclick="viewTab(${idx})"><i class="fas fa-eye"></i></button>
                        <button class="btn ${task.running ? 'btn-d' : 'btn-p'}" onclick="toggleTask(${idx})">
                            <i class="fas fa-${task.running ? 'stop' : 'play'}"></i>
                        </button>
                        <button class="btn btn-s" onclick="removeTask(${idx})" style="color: #ef4444;"><i class="fas fa-trash"></i></button>
                    </div>
                `;
                list.appendChild(item);
            });
        }

        async function addTask() {
            const url = document.getElementById('colabUrl').value;
            if(!url) return;
            const res = await api('/tasks', 'POST', { url });
            if(res.success) {
                addLog('Added new automation tab', 'success');
                document.getElementById('colabUrl').value = '';
                updateStatus();
            }
        }

        async function toggleTask(idx) {
            await api(`/tasks/${idx}/toggle`, 'POST');
            updateStatus();
        }

        async function removeTask(idx) {
            if(!confirm('Delete this automation tab?')) return;
            await api(`/tasks/${idx}`, 'DELETE');
            updateStatus();
        }

        async function viewTab(idx) {
            selectedTabIdx = idx;
            const preview = document.getElementById('previewBox');
            preview.innerHTML = '<i class="fas fa-spinner fa-spin fa-2x" style="color: #6366f1;"></i>';
            const res = await api(`/tasks/${idx}/screenshot`);
            if(res.success) {
                preview.innerHTML = `<img src="/screenshots/${res.filename}?t=${Date.now()}" alt="Preview">`;
            } else {
                preview.innerHTML = '<p>Failed to capture screenshot</p>';
            }
        }

        async function refreshCookies() {
            const res = await api('/cookies/refresh', 'POST');
            if(res.success) addLog(`Cookies updated: ${res.count} items`, 'success');
        }

        async function restartBrowser() {
            addLog('Force restarting browser context...', 'error');
            await api('/browser/restart', 'POST');
            setTimeout(updateStatus, 3000);
        }

        function clearLogs() { document.getElementById('logBox').innerHTML = ''; }

        setInterval(updateStatus, 5000);
        window.onload = () => {
            addLog('System Initialized. Koyeb RAM Protection Active.');
            updateStatus();
        };
    </script>
</body>
</html>
EOF

# --- PYTHON BACKEND (main.py) ---
RUN cat > main.py << 'EOF'
import asyncio
import os
import time
import uuid
import logging
import psutil
import requests
from datetime import datetime
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from playwright.async_api import async_playwright

# Setup Clean Logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(message)s")
logger = logging.getLogger("ColabBot")

app = FastAPI()
templates = Jinja2Templates(directory="templates")
app.mount("/screenshots", StaticFiles(directory="screenshots"), name="screenshots")

# Persistent State
class GlobalState:
    def __init__(self):
        self.pw = None
        self.browser = None
        self.context = None
        self.tasks = [] # List of dict: {"url": str, "page": Page, "running": bool}
        self.cookies = []
        self.lock = asyncio.Lock() # Prevents overlapping keypresses
        self.is_restarting = False
        self.cookies_url = "https://drive.usercontent.google.com/download?id=1NFy-Y6hnDlIDEyFnWSvLOxm4_eyIRsvm&export=download"

state = GlobalState()

def parse_netscape(content):
    cookies = []
    for line in content.splitlines():
        if not line.strip() or line.startswith('#'): continue
        p = line.split('\t')
        if len(p) >= 7:
            cookies.append({
                "name": p[5], "value": p[6], "domain": p[0],
                "path": p[2], "secure": p[3].lower() == "true"
            })
    return cookies

async def get_mem():
    process = psutil.Process(os.getpid())
    mem = process.memory_info().rss / (1024 * 1024)
    for child in process.children(recursive=True):
        try: mem += child.memory_info().rss / (1024 * 1024)
        except: pass
    return round(mem, 1)

async def init_browser():
    if state.is_restarting: return
    state.is_restarting = True
    try:
        logger.info(">>> INITIALIZING BROWSER (RAM OPTIMIZED)")
        # Cleanup
        if state.context: await state.context.close()
        if state.browser: await state.browser.close()
        if state.pw: await state.pw.stop()

        # Download Cookies
        try:
            r = requests.get(state.cookies_url, timeout=10)
            if r.status_code == 200:
                state.cookies = parse_netscape(r.text)
                logger.info(f"Loaded {len(state.cookies)} cookies")
        except Exception as e:
            logger.error(f"Cookie load failed: {e}")

        state.pw = await async_playwright().start()
        state.browser = await state.pw.chromium.launch(
            headless=True,
            args=[
                '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu',
                '--js-flags="--max-old-space-size=256"', # Limit JS Heap
                '--disable-extensions', '--no-zygote', '--single-process'
            ]
        )
        state.context = await state.browser.new_context(
            viewport={'width': 1280, 'height': 720},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        
        if state.cookies:
            await state.context.add_cookies(state.cookies)

        # Restore Tabs if any
        for task in state.tasks:
            task["page"] = await state.context.new_page()
            try:
                await task["page"].goto(task["url"], wait_until="domcontentloaded", timeout=60000)
            except: pass
            
        logger.info(">>> BROWSER SYSTEM ONLINE")
    except Exception as e:
        logger.error(f"Browser Init Error: {e}")
    finally:
        state.is_restarting = False

async def watchdog():
    """Health check every 20 seconds."""
    while True:
        await asyncio.sleep(20)
        if not state.is_restarting:
            try:
                if not state.browser or not state.browser.is_connected():
                    logger.info("!!! HEALTH CHECK FAILED: RESTARTING")
                    await init_browser()
            except:
                await init_browser()

async def automation_loop():
    """Runs every 5 mins for each active tab."""
    while True:
        await asyncio.sleep(300) # 5 Minute Interval
        if state.is_restarting or not state.context: continue
        
        for task in state.tasks:
            if task["running"] and task["page"]:
                async with state.lock: # Anti-collision Lock
                    try:
                        p = task["page"]
                        logger.info(f"Keep-alive: {task['url'][:40]}")
                        await p.bring_to_front()
                        await p.focus('body')
                        await p.keyboard.down('Control')
                        await p.keyboard.press('Enter')
                        await p.keyboard.up('Control')
                        await asyncio.sleep(3) # Wait for execution to start
                    except Exception as e:
                        logger.error(f"Tab automation error: {e}")

@app.on_event("startup")
async def on_start():
    asyncio.create_task(init_browser())
    asyncio.create_task(watchdog())
    asyncio.create_task(automation_loop())

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/status")
async def get_status():
    return {
        "browser_ready": state.browser.is_connected() if state.browser else False,
        "memory_usage": await get_mem(),
        "tasks": [{"url": t["url"], "running": t["running"]} for t in state.tasks]
    }

@app.post("/tasks")
async def add_task(request: Request):
    data = await request.json()
    url = data.get("url")
    if not url: return {"success": False}
    
    if not state.context: await init_browser()
    
    page = await state.context.new_page()
    try:
        await page.goto(url, wait_until="domcontentloaded", timeout=60000)
    except Exception as e:
        logger.warning(f"Initial navigation slow: {e}")

    state.tasks.append({"url": url, "page": page, "running": True})
    return {"success": True}

@app.post("/tasks/{idx}/toggle")
async def toggle_task(idx: int):
    if 0 <= idx < len(state.tasks):
        state.tasks[idx]["running"] = not state.tasks[idx]["running"]
        return {"success": True}
    return {"success": False}

@app.delete("/tasks/{idx}")
async def delete_task(idx: int):
    if 0 <= idx < len(state.tasks):
        task = state.tasks.pop(idx)
        try: await task["page"].close()
        except: pass
        return {"success": True}
    return {"success": False}

@app.get("/tasks/{idx}/screenshot")
async def get_ss(idx: int):
    if 0 <= idx < len(state.tasks):
        page = state.tasks[idx]["page"]
        fname = f"ss_{idx}_{int(time.time())}.png"
        fpath = f"screenshots/{fname}"
        try:
            # Clean old screenshots first
            for f in os.listdir("screenshots"):
                if f.startswith(f"ss_{idx}_"): os.remove(f"screenshots/{f}")
            
            await page.screenshot(path=fpath)
            return {"success": True, "filename": fname}
        except Exception as e:
            return {"success": False, "error": str(e)}
    return {"success": False}

@app.post("/cookies/refresh")
async def refresh_cookies():
    try:
        r = requests.get(state.cookies_url, timeout=10)
        if r.status_code == 200:
            state.cookies = parse_netscape(r.text)
            if state.context:
                await state.context.clear_cookies()
                await state.context.add_cookies(state.cookies)
            return {"success": True, "count": len(state.cookies)}
    except: pass
    return {"success": False}

@app.post("/browser/restart")
async def restart_browser():
    asyncio.create_task(init_browser())
    return {"success": True}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)), log_level="warning")
EOF

# Expose port
EXPOSE 8000

# Start command
CMD ["python", "main.py"]

