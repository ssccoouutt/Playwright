FROM python:3.11-slim

# Install system dependencies for Playwright
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

# Install Python packages
RUN pip install playwright==1.40.0 fastapi==0.104.1 uvicorn==0.24.0 python-multipart jinja2 requests psutil

# Install Chromium
RUN playwright install chromium

# Create directories
RUN mkdir -p templates screenshots

# --- DASHBOARD UI ---
RUN cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>🤖 Colab Guard Pro</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
        :root { --primary: #8b5cf6; --bg: #020617; --card: #0f172a; --text: #f1f5f9; }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', system-ui, sans-serif; }
        body { background: var(--bg); color: var(--text); padding: 15px; }
        .container { max-width: 1000px; margin: 0 auto; }
        .card { background: var(--card); border-radius: 12px; padding: 20px; border: 1px solid #1e293b; margin-bottom: 15px; box-shadow: 0 10px 15px -3px rgba(0,0,0,0.4); }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .status-badge { font-size: 12px; padding: 4px 10px; border-radius: 20px; font-weight: bold; background: #1e293b; }
        .alive { color: #4ade80; border: 1px solid #064e3b; }
        .dead { color: #f87171; border: 1px solid #7f1d1d; }
        .input-group { display: flex; gap: 8px; margin-bottom: 15px; }
        input { flex: 1; padding: 10px; border-radius: 6px; border: 1px solid #334155; background: #020617; color: white; outline: none; }
        input:focus { border-color: var(--primary); }
        .btn { padding: 8px 16px; border-radius: 6px; border: none; cursor: pointer; font-weight: 600; transition: 0.2s; color: white; display: flex; align-items: center; gap: 6px; }
        .btn-p { background: var(--primary); }
        .btn-d { background: #ef4444; }
        .btn-s { background: #334155; }
        .task-list { display: flex; flex-direction: column; gap: 8px; }
        .task-item { background: #1e293b; padding: 12px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; }
        .task-url { font-size: 12px; color: #94a3b8; max-width: 250px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
        .log-box { background: #000; color: #10b981; padding: 10px; border-radius: 6px; height: 250px; overflow-y: auto; font-family: monospace; font-size: 11px; line-height: 1.4; border: 1px solid #1e293b; }
        .grid { display: grid; grid-template-columns: 1fr 320px; gap: 15px; }
        @media (max-width: 800px) { .grid { grid-template-columns: 1fr; } }
        .stats { display: flex; justify-content: space-around; margin-top: 10px; }
        .stat-item { text-align: center; }
        .stat-val { font-size: 18px; font-weight: bold; display: block; }
        .stat-lbl { font-size: 10px; color: #64748b; text-transform: uppercase; }
        .preview-img { width: 100%; border-radius: 6px; border: 1px solid #334155; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1><i class="fas fa-shield-halved"></i> Colab Guard Pro</h1>
            <div id="bStatus" class="status-badge dead">Connecting...</div>
        </header>

        <div class="grid">
            <main>
                <div class="card">
                    <h3><i class="fas fa-plus"></i> New Automation Tab</h3>
                    <div class="input-group" style="margin-top:12px">
                        <input type="url" id="colabUrl" placeholder="Paste Colab Drive URL here...">
                        <button class="btn btn-p" onclick="addTask()">Add</button>
                    </div>
                </div>
                <div class="card">
                    <h3><i class="fas fa-microchip"></i> Active Tabs</h3>
                    <div id="taskList" class="task-list" style="margin-top:12px"></div>
                </div>
                <div id="ssCard" class="card" style="display:none">
                    <h3><i class="fas fa-camera"></i> Tab Preview</h3>
                    <img id="preview" class="preview-img">
                </div>
            </main>
            <aside>
                <div class="card">
                    <h3><i class="fas fa-chart-line"></i> Performance</h3>
                    <div class="stats">
                        <div class="stat-item"><span id="mem" class="stat-val">0</span><span class="stat-lbl">RAM (MB)</span></div>
                        <div class="stat-item"><span id="sessSize" class="stat-val">0</span><span class="stat-lbl">SESS (KB)</span></div>
                    </div>
                    <div style="margin-top:15px; display:grid; gap:8px">
                        <button class="btn btn-s" onclick="relaunch()"><i class="fas fa-power-off"></i> Force Relaunch</button>
                    </div>
                </div>
                <div class="card">
                    <h3><i class="fas fa-terminal"></i> Activity</h3>
                    <div id="logs" class="log-box"></div>
                </div>
            </aside>
        </div>
    </div>

    <script>
        const log = (msg, isErr = false) => {
            const l = document.getElementById('logs');
            const d = document.createElement('div');
            d.style.color = isErr ? '#f87171' : '#10b981';
            d.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
            l.appendChild(d);
            l.scrollTop = l.scrollHeight;
        };

        async function refresh() {
            try {
                const r = await fetch('/status');
                const d = await r.json();
                const bs = document.getElementById('bStatus');
                bs.className = `status-badge ${d.alive ? 'alive' : 'dead'}`;
                bs.textContent = d.alive ? 'BROWSER ONLINE' : 'ENGINE RESTARTING';
                document.getElementById('mem').textContent = d.memory;
                document.getElementById('sessSize').textContent = d.session_size_kb;

                const list = document.getElementById('taskList');
                list.innerHTML = '';
                d.tasks.forEach((t, i) => {
                    const item = document.createElement('div');
                    item.className = 'task-item';
                    item.innerHTML = `
                        <div style="flex:1">
                            <div style="font-size:11px; color:${t.running?'#4ade80':'#94a3b8'}">${t.running?'● RUNNING':'● STOPPED'}</div>
                            <div class="task-url">${t.url}</div>
                        </div>
                        <div style="display:flex; gap:5px">
                            <button class="btn btn-s" onclick="view(${i})"><i class="fas fa-eye"></i></button>
                            <button class="btn ${t.running?'btn-d':'btn-p'}" onclick="toggle(${i})"><i class="fas fa-${t.running?'stop':'play'}"></i></button>
                            <button class="btn btn-s" onclick="remove(${i})"><i class="fas fa-trash"></i></button>
                        </div>
                    `;
                    list.appendChild(item);
                });
            } catch(e) {}
        }

        async function addTask() {
            const url = document.getElementById('colabUrl').value;
            if(!url) return;
            await fetch('/tasks', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({url})});
            document.getElementById('colabUrl').value = '';
            refresh();
        }

        async function toggle(i) { await fetch(`/tasks/${i}/toggle`, {method:'POST'}); refresh(); }
        async function remove(i) { await fetch(`/tasks/${i}`, {method:'DELETE'}); refresh(); }
        async function relaunch() { await fetch('/relaunch', {method:'POST'}); }

        async function view(i) {
            const r = await fetch(`/tasks/${i}/screenshot`);
            const d = await r.json();
            if(d.success) {
                document.getElementById('ssCard').style.display = 'block';
                document.getElementById('preview').src = `/screenshots/${d.file}?t=${Date.now()}`;
            }
        }

        setInterval(refresh, 5000);
        window.onload = refresh;
    </script>
</body>
</html>
EOF

# --- BACKEND SYSTEM ---
RUN cat > main.py << 'EOF'
import asyncio
import os
import psutil
import logging
import requests
import json
import time
import sys
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from playwright.async_api import async_playwright

# Optimized Logging
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("Bot")

app = FastAPI()
templates = Jinja2Templates(directory="templates")
os.makedirs("screenshots", exist_ok=True)
app.mount("/screenshots", StaticFiles(directory="screenshots"), name="screenshots")

class SessionManager:
    def __init__(self):
        self.pw = None
        self.browser = None
        self.context = None
        self.tasks = [] 
        self.lock = asyncio.Lock()
        self.is_busy = False
        self.storage_state = None 
        self.cookie_url = "https://drive.usercontent.google.com/download?id=1NFy-Y6hnDlIDEyFnWSvLOxm4_eyIRsvm&export=download"
        self.last_sync_success = True

    def parse_netscape(self, text):
        cookies = []
        for line in text.splitlines():
            if not line.strip() or line.startswith('#'): continue
            p = line.split('\t')
            if len(p) >= 7:
                cookies.append({
                    "name": p[5], "value": p[6], "domain": p[0],
                    "path": p[2], "secure": p[3].lower() == "true"
                })
        return cookies

    async def launch(self):
        """Restores browser engine with saved state to prevent logout."""
        if self.is_busy: return
        self.is_busy = True
        
        try:
            logger.info(">>> ENGINE: INITIATING RE-LAUNCH")
            # Sync state one last time before closing if possible
            if self.context:
                await self.sync_state()

            if self.context: await self.context.close()
            if self.browser: await self.browser.close()
            if self.pw: await self.pw.stop()

            self.pw = await async_playwright().start()
            self.browser = await self.pw.chromium.launch(
                headless=True,
                args=[
                    '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu',
                    '--js-flags="--max-old-space-size=128"',
                    '--disable-extensions', '--no-zygote', '--single-process'
                ]
            )
            
            if self.storage_state:
                logger.info(f">>> ENGINE: RESTORING SAVED SESSION...")
                try:
                    self.context = await self.browser.new_context(
                        storage_state=self.storage_state,
                        viewport={'width': 1280, 'height': 720}
                    )
                except Exception as e:
                    logger.warning(f"Failed to restore full state: {e}, trying fallback...")
                    # Fallback 1: Try with just cookies
                    try:
                        self.context = await self.browser.new_context(viewport={'width': 1280, 'height': 720})
                        if self.storage_state and "cookies" in self.storage_state:
                            await self.context.add_cookies(self.storage_state["cookies"])
                        logger.info("Fallback 1: Restored cookies only")
                    except Exception as e2:
                        logger.error(f"Fallback 1 failed: {e2}")
                        # Fallback 2: Clean context with seed cookies
                        self.context = await self.browser.new_context(viewport={'width': 1280, 'height': 720})
                        try:
                            r = requests.get(self.cookie_url, timeout=10)
                            if r.status_code == 200:
                                cookies = self.parse_netscape(r.text)
                                await self.context.add_cookies(cookies)
                        except:
                            pass
                        logger.info("Fallback 2: Clean context created")
            else:
                logger.info(">>> ENGINE: NO SAVED STATE - LOADING SEED COOKIES")
                self.context = await self.browser.new_context(viewport={'width': 1280, 'height': 720})
                try:
                    r = requests.get(self.cookie_url, timeout=10)
                    if r.status_code == 200:
                        cookies = self.parse_netscape(r.text)
                        await self.context.add_cookies(cookies)
                except Exception as e:
                    logger.error(f"!!! COOKIE FETCH FAILED: {e}")

            # FIXED SECTION: Recreate pages for all tasks in order
            for idx, task in enumerate(self.tasks):
                try:
                    # Close old page reference if it exists (but should be closed already)
                    if task.get("page"):
                        try:
                            await task["page"].close()
                        except:
                            pass
                    
                    # Create new page
                    new_page = await self.context.new_page()
                    self.tasks[idx]["page"] = new_page
                    
                    try: 
                        await new_page.goto(task["url"], wait_until="domcontentloaded", timeout=60000)
                        logger.info(f">>> ENGINE: Tab #{idx+1} restored")
                    except Exception as e:
                        logger.error(f">>> ENGINE: Tab #{idx+1} failed to load: {e}")
                        pass
                except Exception as e:
                    logger.error(f">>> ENGINE: Failed to restore tab #{idx+1}: {e}")
                    # Keep the task but mark page as None
                    self.tasks[idx]["page"] = None
            
            logger.info(">>> ENGINE: ONLINE")
            self.last_sync_success = True
        except Exception as e:
            logger.error(f"!!! CRITICAL FAILURE: {e}")
            self.last_sync_success = False
        finally:
            self.is_busy = False

    async def sync_state(self):
        """Saves current session state to memory with optimization for multiple tabs."""
        if not self.context:
            return 0
            
        # Don't try to sync if last sync failed or we're busy
        if not self.last_sync_success or self.is_busy:
            return len(json.dumps(self.storage_state)) // 1024 if self.storage_state else 0
            
        try:
            # Strategy: Save full storage state but with retries
            max_retries = 2
            for attempt in range(max_retries + 1):
                try:
                    # Close inactive tabs before saving state to reduce load
                    active_tabs = []
                    for task in self.tasks:
                        if task.get("page") and not task.get("page").is_closed():
                            active_tabs.append(task["page"])
                    
                    # Save full storage state with timeout based on number of tabs
                    timeout_seconds = 10 + (len(active_tabs) * 5)  # More tabs = more time
                    timeout_seconds = min(timeout_seconds, 30)  # Max 30 seconds
                    
                    logger.info(f"STATE SYNC attempt {attempt+1}/{max_retries+1} ({len(active_tabs)} tabs, timeout: {timeout_seconds}s)")
                    
                    self.storage_state = await asyncio.wait_for(
                        self.context.storage_state(),
                        timeout=timeout_seconds
                    )
                    
                    size_kb = len(json.dumps(self.storage_state)) // 1024
                    cookie_count = len(self.storage_state.get("cookies", [])) if self.storage_state else 0
                    logger.info(f"STATE SYNCED: {size_kb} KB ({cookie_count} cookies)")
                    self.last_sync_success = True
                    return size_kb
                    
                except asyncio.TimeoutError:
                    if attempt < max_retries:
                        logger.warning(f"STATE SYNC: Timeout on attempt {attempt+1}, retrying...")
                        await asyncio.sleep(2)  # Wait before retry
                    else:
                        logger.error("STATE SYNC: All attempts timed out")
                        self.last_sync_success = False
                        # Keep old state if sync fails
                        return len(json.dumps(self.storage_state)) // 1024 if self.storage_state else 0
                        
                except Exception as e:
                    logger.error(f"STATE SYNC error: {e}")
                    if attempt < max_retries:
                        await asyncio.sleep(1)
                    else:
                        self.last_sync_success = False
                        return len(json.dumps(self.storage_state)) // 1024 if self.storage_state else 0
                        
        except Exception as e:
            logger.error(f"STATE SYNC unexpected error: {e}")
            self.last_sync_success = False
            
        return len(json.dumps(self.storage_state)) // 1024 if self.storage_state else 0

mgr = SessionManager()

async def watchdog():
    """Relaunches browser every 15 minutes as requested."""
    while True:
        await asyncio.sleep(900) # Exactly 15 minutes
        if mgr.is_busy: continue
        
        logger.info(">>> WATCHDOG: 15-MIN SCHEDULED RELAUNCH")
        await mgr.launch()

async def automation():
    """Sequential automation every 5 minutes."""
    while True:
        await asyncio.sleep(300)
        if mgr.is_busy or not mgr.context: continue
        
        # FIXED SECTION: Check if page is still valid before using it
        for idx, task in enumerate(mgr.tasks):
            if task["running"] and task.get("page"):
                async with mgr.lock:
                    try:
                        logger.info(f"KEEP-ALIVE: Tab #{idx+1}")
                        p = task["page"]
                        
                        # Check if page is still valid
                        if p.is_closed():
                            logger.warning(f"Tab #{idx+1} is closed, skipping")
                            continue
                            
                        await p.bring_to_front()
                        await p.keyboard.down('Control')
                        await p.keyboard.press('Enter')
                        await p.keyboard.up('Control')
                        await asyncio.sleep(2) 
                    except Exception as e:
                        logger.warning(f"KEEP-ALIVE failed for Tab #{idx+1}: {e}")

@app.on_event("startup")
async def start():
    asyncio.create_task(mgr.launch())
    asyncio.create_task(watchdog())
    asyncio.create_task(automation())

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/status")
async def get_status():
    proc = psutil.Process(os.getpid())
    mem = proc.memory_info().rss / (1024*1024)
    for c in proc.children(recursive=True):
        try: mem += c.memory_info().rss / (1024*1024)
        except: pass
    size_kb = len(json.dumps(mgr.storage_state)) // 1024 if mgr.storage_state else 0
    return {
        "alive": mgr.browser.is_connected() if mgr.browser else False,
        "memory": int(mem),
        "session_size_kb": size_kb,
        "tasks": [{"url": t["url"], "running": t["running"]} for t in mgr.tasks]
    }

@app.post("/tasks")
async def add_task(request: Request):
    data = await request.json()
    url = data.get("url")
    if not url or not mgr.context: return {"success": False}
    pg = await mgr.context.new_page()
    try: await pg.goto(url, wait_until="domcontentloaded", timeout=60000)
    except: pass
    mgr.tasks.append({"url": url, "page": pg, "running": True})
    
    # Save session immediately when adding a tab
    await mgr.sync_state()
    return {"success": True}

@app.post("/tasks/{idx}/toggle")
async def toggle(idx: int):
    if 0 <= idx < len(mgr.tasks):
        mgr.tasks[idx]["running"] = not mgr.tasks[idx]["running"]
    return {"success": True}

@app.delete("/tasks/{idx}")
async def remove(idx: int):
    if 0 <= idx < len(mgr.tasks):
        t = mgr.tasks.pop(idx)
        try: await t["page"].close()
        except: pass
        
        # Save session immediately when removing a tab (size will decrease)
        await mgr.sync_state()
    return {"success": True}

@app.get("/tasks/{idx}/screenshot")
async def ss(idx: int):
    if 0 <= idx < len(mgr.tasks):
        name = f"ss_{idx}.png"
        path = f"screenshots/{name}"
        try:
            await mgr.tasks[idx]["page"].screenshot(path=path)
            return {"success": True, "file": name}
        except: pass
    return {"success": False}

@app.post("/relaunch")
async def relaunch():
    asyncio.create_task(mgr.launch())
    return {"success": True}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)), log_level="warning")
EOF

EXPOSE 8000
CMD ["python", "main.py"]
