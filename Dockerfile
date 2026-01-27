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
RUN pip install playwright==1.40.0 fastapi==0.104.1 uvicorn==0.24.0 python-multipart jinja2 requests psutil google-api-python-client google-auth google-auth-oauthlib google-auth-httplib2

# Install Chromium
RUN playwright install chromium

# Create directories
RUN mkdir -p templates

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
        .btn-c { background: #f59e0b; }
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
        .cookie-input { margin-top: 10px; }
        .cookie-input textarea { width: 100%; background: #1e293b; color: white; border: 1px solid #334155; border-radius: 6px; padding: 10px; font-family: monospace; font-size: 11px; resize: vertical; min-height: 80px; }
        .drive-badge { font-size: 10px; background: #1e40af; color: #93c5fd; padding: 2px 6px; border-radius: 10px; margin-left: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1><i class="fas fa-shield-halved"></i> Colab Guard Pro <span class="drive-badge">Google Drive</span></h1>
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
                        <div class="stat-item"><span id="driveState" class="stat-val">❓</span><span class="stat-lbl">DRIVE STATE</span></div>
                    </div>
                    <div style="margin-top:15px; display:grid; gap:8px">
                        <button class="btn btn-c" onclick="loadCookies()"><i class="fas fa-cookie-bite"></i> Load Fresh Cookies</button>
                        <button class="btn btn-s" onclick="relaunch()"><i class="fas fa-power-off"></i> Force Relaunch</button>
                    </div>
                </div>
                <div class="card">
                    <h3><i class="fas fa-terminal"></i> Activity</h3>
                    <div id="logs" class="log-box"></div>
                </div>
                <div class="card">
                    <h3><i class="fas fa-cookie"></i> Load Custom Cookies</h3>
                    <div class="cookie-input">
                        <textarea id="cookieText" placeholder="Paste Netscape format cookies here..."></textarea>
                        <button class="btn btn-p" onclick="loadCustomCookies()" style="margin-top:8px; width:100%">
                            <i class="fas fa-upload"></i> Load Cookies
                        </button>
                    </div>
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
                document.getElementById('driveState').textContent = d.drive_state;

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
                document.getElementById('preview').src = `/screenshot/${i}?t=${Date.now()}`;
            }
        }

        async function loadCookies() {
            try {
                const response = await fetch('/load-cookies', {method:'POST'});
                const result = await response.json();
                if(result.success) {
                    log(`✅ ${result.message}`);
                    // Relaunch browser to apply cookies
                    await relaunch();
                } else {
                    log(`❌ ${result.message}`, true);
                }
            } catch(e) {
                log(`❌ Cookie load failed: ${e}`, true);
            }
        }

        async function loadCustomCookies() {
            const cookieText = document.getElementById('cookieText').value;
            if(!cookieText.trim()) {
                log('❌ Please paste cookies first', true);
                return;
            }
            
            try {
                const response = await fetch('/load-custom-cookies', {
                    method: 'POST',
                    headers: {'Content-Type':'application/json'},
                    body: JSON.stringify({cookies: cookieText})
                });
                const result = await response.json();
                if(result.success) {
                    log(`✅ ${result.message}`);
                    document.getElementById('cookieText').value = '';
                    // Relaunch browser to apply cookies
                    await relaunch();
                } else {
                    log(`❌ ${result.message}`, true);
                }
            } catch(e) {
                log(`❌ Cookie load failed: ${e}`, true);
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
import io
import base64
from datetime import datetime, timedelta
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, StreamingResponse
from fastapi.templating import Jinja2Templates
from playwright.async_api import async_playwright
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.http import MediaIoBaseUpload, MediaIoBaseDownload

# Minimal Logging - Only important info
logging.basicConfig(level=logging.INFO, format="%(message)s")
logger = logging.getLogger("Bot")

app = FastAPI()
templates = Jinja2Templates(directory="templates")

# Hardcoded Google Drive credentials
DRIVE_CREDENTIALS = {
    "token": "ya29.a0AS3H6NzvntITO1LFz3T3we5n9mQGiY6KqA2TKzpWhppuUalPdG-shWjvTljC_TbYcWigReEc_T38nDHrn11Rscr6PPRzY1YR59zZQQztj4crL7d9cuc4X2OC0Hz5Q-1OIqSJcH6GSERBZEhUIMgh6sOBYr1jzdhj4w6Gu6hfaCgYKAfESARQSFQHGX2Mijb2Oudks2xwUOQ-DQ3hqzw0175",
    "refresh_token": "1//03P2kdvxV8pieCgYIARAAGAMSNwF-L9Irg_RYyNkqsFYHnKNYhhw-wQXaJzbLiT8cn_JMn7gToeRiivW8uwdab3475J8dNB8Mq6k",
    "token_uri": "https://oauth2.googleapis.com/token",
    "client_id": "704057951722-2llchdubr050n3v0shmf2omslhv6t8v7.apps.googleusercontent.com",
    "client_secret": "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",
    "scopes": ["https://www.googleapis.com/auth/drive"],
    "universe_domain": "googleapis.com",
    "account": "",
    "expiry": "2025-07-09T08:28:54.969314Z"
}

# Drive file IDs
STATE_FILE_ID = "1NZ3NvyVBnK85S8f5eTZJS5uM5c59xvGM"  # Your token file ID - will use for state
COOKIE_FILE_ID = "1NFy-Y6hnDlIDEyFnWSvLOxm4_eyIRsvm"  # Your cookie file ID
SCREENSHOT_FOLDER_ID = None  # Will create if doesn't exist

class GoogleDriveManager:
    def __init__(self):
        self.creds = None
        self.service = None
        self.screenshot_folder_id = None
        self.initialize()
    
    def initialize(self):
        """Initialize Google Drive API with hardcoded credentials."""
        try:
            # Create credentials from hardcoded token
            self.creds = Credentials.from_authorized_user_info(DRIVE_CREDENTIALS)
            
            # Check if token is expired or about to expire
            expiry_time = datetime.fromisoformat(DRIVE_CREDENTIALS["expiry"].replace('Z', '+00:00'))
            if datetime.utcnow() + timedelta(minutes=5) > expiry_time:
                logger.warning("⚠️ Drive token expired/expiring soon - may need refresh")
            
            # Build service
            self.service = build('drive', 'v3', credentials=self.creds)
            
            # Find or create screenshot folder
            self.find_or_create_screenshot_folder()
            
            logger.info("✅ Google Drive initialized")
            return True
        except Exception as e:
            logger.error(f"❌ Drive initialization failed: {e}")
            return False
    
    def find_or_create_screenshot_folder(self):
        """Find or create 'ColabGuard_Screenshots' folder."""
        try:
            # Search for existing folder
            response = self.service.files().list(
                q="name='ColabGuard_Screenshots' and mimeType='application/vnd.google-apps.folder' and trashed=false",
                spaces='drive',
                fields='files(id, name)'
            ).execute()
            
            if response['files']:
                self.screenshot_folder_id = response['files'][0]['id']
                logger.info(f"✅ Found screenshot folder: {self.screenshot_folder_id}")
            else:
                # Create new folder
                folder_metadata = {
                    'name': 'ColabGuard_Screenshots',
                    'mimeType': 'application/vnd.google-apps.folder'
                }
                folder = self.service.files().create(body=folder_metadata, fields='id').execute()
                self.screenshot_folder_id = folder['id']
                logger.info(f"✅ Created screenshot folder: {self.screenshot_folder_id}")
                
        except Exception as e:
            logger.error(f"❌ Screenshot folder setup failed: {e}")
    
    async def save_state_to_drive(self, state_data):
        """Save browser state to Google Drive."""
        try:
            state_json = json.dumps(state_data, indent=2)
            
            # Create in-memory file
            state_bytes = state_json.encode('utf-8')
            state_io = io.BytesIO(state_bytes)
            
            # Update existing file
            media = MediaIoBaseUpload(state_io, mimetype='application/json')
            file_metadata = {'name': 'colab_guard_state.json'}
            
            self.service.files().update(
                fileId=STATE_FILE_ID,
                body=file_metadata,
                media_body=media
            ).execute()
            
            size_kb = len(state_json) // 1024
            logger.info(f"✅ State saved to Drive: {size_kb} KB")
            return size_kb
            
        except Exception as e:
            logger.error(f"❌ Drive save failed: {e}")
            return 0
    
    async def load_state_from_drive(self):
        """Load browser state from Google Drive."""
        try:
            # Download file
            request = self.service.files().get_media(fileId=STATE_FILE_ID)
            state_io = io.BytesIO()
            downloader = MediaIoBaseDownload(state_io, request)
            done = False
            while not done:
                status, done = downloader.next_chunk()
            
            state_json = state_io.getvalue().decode('utf-8')
            state_data = json.loads(state_json)
            
            size_kb = len(state_json) // 1024
            cookie_count = len(state_data.get('cookies', []))
            logger.info(f"✅ State loaded from Drive: {size_kb} KB ({cookie_count} cookies)")
            return state_data
            
        except Exception as e:
            logger.error(f"❌ Drive load failed: {e}")
            return None
    
    async def save_screenshot_to_drive(self, screenshot_bytes, filename):
        """Save screenshot to Google Drive."""
        try:
            if not self.screenshot_folder_id:
                logger.error("❌ No screenshot folder configured")
                return None
            
            # Create in-memory file
            screenshot_io = io.BytesIO(screenshot_bytes)
            
            # Upload to Drive
            media = MediaIoBaseUpload(screenshot_io, mimetype='image/png')
            file_metadata = {
                'name': filename,
                'parents': [self.screenshot_folder_id]
            }
            
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, webViewLink'
            ).execute()
            
            logger.info(f"✅ Screenshot saved to Drive: {filename}")
            return file.get('id')
            
        except Exception as e:
            logger.error(f"❌ Screenshot save failed: {e}")
            return None
    
    def get_drive_status(self):
        """Get Google Drive connection status."""
        if not self.service:
            return "❌ NOT CONNECTED"
        try:
            # Simple test query
            self.service.files().list(pageSize=1, fields="files(id)").execute()
            return "✅ CONNECTED"
        except Exception as e:
            return f"⚠️ ERROR: {str(e)[:30]}"

class SessionManager:
    def __init__(self, drive_manager):
        self.pw = None
        self.browser = None
        self.context = None
        self.tasks = [] 
        self.lock = asyncio.Lock()
        self.is_busy = False
        self.storage_state = None 
        self.drive = drive_manager
        self.cookie_file_id = COOKIE_FILE_ID
    
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
    
    async def check_google_login(self, page):
        """Check if Google account is logged in."""
        try:
            await page.goto("https://accounts.google.com", wait_until="domcontentloaded", timeout=10000)
            await asyncio.sleep(2)
            
            page_text = await page.content()
            page_url = page.url
            
            if "signin" in page_url.lower() or "Sign in" in page_text or "sign in" in page_text.lower():
                logger.warning("⚠️ GOOGLE LOGGED OUT")
                return False
            else:
                logger.info("✅ Google logged in")
                return True
        except Exception as e:
            logger.warning(f"⚠️ Login check failed: {e}")
            return False

    async def launch(self):
        """Restores browser engine with saved state from Google Drive."""
        if self.is_busy: return
        self.is_busy = True
        
        try:
            logger.info(">>> ENGINE: INITIATING RE-LAUNCH")
            
            # Save state before closing (if we have a context)
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
            
            # Try to load state from Google Drive
            loaded_state = await self.drive.load_state_from_drive()
            if loaded_state:
                logger.info(">>> RESTORING STATE FROM DRIVE...")
                try:
                    self.context = await self.browser.new_context(
                        storage_state=loaded_state,
                        viewport={'width': 1280, 'height': 720}
                    )
                    self.storage_state = loaded_state
                    logger.info(">>> STATE RESTORED SUCCESSFULLY")
                except Exception as e:
                    logger.error(f">>> Failed to restore state: {e}")
                    self.context = await self.browser.new_context(viewport={'width': 1280, 'height': 720})
            else:
                # Fresh launch with seed cookies
                logger.info(">>> FRESH LAUNCH - LOADING SEED COOKIES")
                self.context = await self.browser.new_context(viewport={'width': 1280, 'height': 720})
                await self.load_seed_cookies()

            # Check login status
            check_page = await self.context.new_page()
            is_logged_in = await self.check_google_login(check_page)
            await check_page.close()
            
            if not is_logged_in:
                logger.warning("⚠️ ACCOUNT LOGGED OUT - Opening login page")
                login_page = await self.context.new_page()
                await login_page.goto("https://accounts.google.com", wait_until="domcontentloaded")
                logger.info("⚠️ Please login manually at: https://accounts.google.com")

            # Restore all tabs
            for idx, task in enumerate(self.tasks):
                try:
                    new_page = await self.context.new_page()
                    self.tasks[idx]["page"] = new_page
                    await new_page.goto(task["url"], wait_until="domcontentloaded", timeout=60000)
                    logger.info(f">>> Tab #{idx+1} restored")
                except Exception as e:
                    logger.warning(f">>> Tab #{idx+1} error: {e}")
            
            logger.info(">>> ENGINE ONLINE")
        except Exception as e:
            logger.error(f"❌ CRITICAL FAILURE: {e}")
        finally:
            self.is_busy = False

    async def load_seed_cookies(self):
        """Load seed cookies from Google Drive."""
        try:
            # Download cookie file from Drive
            request = self.drive.service.files().get_media(fileId=self.cookie_file_id)
            cookie_io = io.BytesIO()
            downloader = MediaIoBaseDownload(cookie_io, request)
            done = False
            while not done:
                status, done = downloader.next_chunk()
            
            cookie_text = cookie_io.getvalue().decode('utf-8')
            cookies = self.parse_netscape(cookie_text)
            
            if cookies:
                await self.context.add_cookies(cookies)
                logger.info(f">>> Loaded {len(cookies)} seed cookies")
            else:
                logger.warning(">>> No cookies parsed from seed file")
                
        except Exception as e:
            logger.error(f"!!! COOKIE LOAD FAILED: {e}")

    async def sync_state(self):
        """TELEGRAM BOT STRATEGY: Save full browser state to Google Drive."""
        if not self.context:
            return 0
            
        try:
            logger.info(">>> SAVING FULL STATE TO DRIVE...")
            
            # TELEGRAM BOT CORE LOGIC: Save complete storage state
            self.storage_state = await self.context.storage_state()
            
            # Save to Google Drive
            size_kb = await self.drive.save_state_to_drive(self.storage_state)
            
            if size_kb > 0:
                cookie_count = len(self.storage_state.get('cookies', [])) if self.storage_state else 0
                logger.info(f">>> STATE SAVED: {size_kb} KB ({cookie_count} cookies)")
                return size_kb
            else:
                logger.error("❌ Drive save returned 0")
                return 0
                
        except Exception as e:
            logger.error(f"❌ STATE SAVE FAILED: {e}")
            return len(json.dumps(self.storage_state)) // 1024 if self.storage_state else 0

# Initialize managers
drive_manager = GoogleDriveManager()
mgr = SessionManager(drive_manager)

async def watchdog():
    """Relaunches browser every 15 minutes."""
    while True:
        await asyncio.sleep(900)
        if mgr.is_busy: continue
        
        logger.info(">>> SCHEDULED RELAUNCH")
        await mgr.launch()

async def automation():
    """Sequential automation every 5 minutes."""
    while True:
        await asyncio.sleep(300)
        if mgr.is_busy or not mgr.context: continue
        
        for idx, task in enumerate(mgr.tasks):
            if task["running"] and task.get("page"):
                async with mgr.lock:
                    try:
                        p = task["page"]
                        if p.is_closed():
                            continue
                            
                        await p.bring_to_front()
                        await p.keyboard.down('Control')
                        await p.keyboard.press('Enter')
                        await p.keyboard.up('Control')
                        await asyncio.sleep(2)
                    except Exception:
                        pass  # Silent fail for keep-alive

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
    drive_status = drive_manager.get_drive_status()
    
    return {
        "alive": mgr.browser.is_connected() if mgr.browser else False,
        "memory": int(mem),
        "drive_state": drive_status,
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
        
        await mgr.sync_state()
    return {"success": True}

@app.get("/screenshot/{idx}")
async def get_screenshot(idx: int):
    if 0 <= idx < len(mgr.tasks):
        try:
            screenshot = await mgr.tasks[idx]["page"].screenshot()
            
            # Save to Drive
            filename = f"screenshot_{idx}_{int(time.time())}.png"
            file_id = await drive_manager.save_screenshot_to_drive(screenshot, filename)
            
            if file_id:
                # Return the screenshot directly
                return StreamingResponse(
                    io.BytesIO(screenshot),
                    media_type="image/png",
                    headers={"Content-Disposition": f"inline; filename={filename}"}
                )
        except:
            pass
    raise HTTPException(status_code=404, detail="Screenshot failed")

@app.post("/load-cookies")
async def load_cookies():
    """Load fresh cookies from Google Drive."""
    if not mgr.context:
        return {"success": False, "message": "Browser not ready"}
    
    try:
        # Download fresh cookies
        request = drive_manager.service.files().get_media(fileId=mgr.cookie_file_id)
        cookie_io = io.BytesIO()
        downloader = MediaIoBaseDownload(cookie_io, request)
        done = False
        while not done:
            status, done = downloader.next_chunk()
        
        cookie_text = cookie_io.getvalue().decode('utf-8')
        cookies = mgr.parse_netscape(cookie_text)
        
        if cookies:
            # Clear existing cookies and add fresh ones
            await mgr.context.clear_cookies()
            await mgr.context.add_cookies(cookies)
            
            # Apply to all tabs
            for task in mgr.tasks:
                if task.get("page") and not task["page"].is_closed():
                    try:
                        await task["page"].reload(wait_until="domcontentloaded")
                    except:
                        pass
            
            logger.info(f"✅ Loaded {len(cookies)} fresh cookies")
            return {"success": True, "message": f"Loaded {len(cookies)} fresh cookies"}
        else:
            return {"success": False, "message": "No valid cookies found"}
            
    except Exception as e:
        logger.error(f"❌ Cookie load failed: {e}")
        return {"success": False, "message": f"Cookie load failed: {str(e)}"}

@app.post("/load-custom-cookies")
async def load_custom_cookies(request: Request):
    """Load custom cookies from user input."""
    if not mgr.context:
        return {"success": False, "message": "Browser not ready"}
    
    data = await request.json()
    cookie_text = data.get("cookies", "")
    
    if not cookie_text:
        return {"success": False, "message": "No cookies provided"}
    
    try:
        cookies = mgr.parse_netscape(cookie_text)
        if not cookies:
            return {"success": False, "message": "No valid cookies found in text"}
        
        # Clear existing cookies and add fresh ones
        await mgr.context.clear_cookies()
        await mgr.context.add_cookies(cookies)
        
        # Apply to all tabs
        for task in mgr.tasks:
            if task.get("page") and not task["page"].is_closed():
                try:
                    await task["page"].reload(wait_until="domcontentloaded")
                except:
                    pass
        
        logger.info(f"✅ Loaded {len(cookies)} custom cookies")
        return {"success": True, "message": f"Loaded {len(cookies)} custom cookies"}
    except Exception as e:
        logger.error(f"❌ Custom cookie load failed: {e}")
        return {"success": False, "message": f"Cookie load failed: {str(e)}"}

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
