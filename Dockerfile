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
RUN pip install playwright==1.40.0 fastapi==0.104.1 uvicorn==0.24.0 python-multipart jinja2 requests psutil google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client

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
        .permanent-tag { font-size: 9px; background: #1e40af; color: #93c5fd; padding: 2px 6px; border-radius: 10px; margin-left: 5px; }
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
                    <h3><i class="fas fa-microchip"></i> Active Tabs <span style="font-size:11px; color:#94a3b8">(Google.com is permanent first tab)</span></h3>
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
                document.getElementById('sessSize').textContent = d.session_size_kb;

                const list = document.getElementById('taskList');
                list.innerHTML = '';
                d.tasks.forEach((t, i) => {
                    const item = document.createElement('div');
                    item.className = 'task-item';
                    const isPermanent = t.url.includes('colab.research.google.com') && i === 0;
                    item.innerHTML = `
                        <div style="flex:1">
                            <div style="display:flex; align-items:center">
                                <div style="font-size:11px; color:${t.running?'#4ade80':'#94a3b8'}">
                                    ${t.running?'● RUNNING':'● STOPPED'}
                                </div>
                                ${isPermanent ? '<span class="permanent-tag">PERMANENT</span>' : ''}
                            </div>
                            <div class="task-url">${t.url}</div>
                        </div>
                        <div style="display:flex; gap:5px">
                            <button class="btn btn-s" onclick="view(${i})"><i class="fas fa-eye"></i></button>
                            ${!isPermanent ? `
                                <button class="btn ${t.running?'btn-d':'btn-p'}" onclick="toggle(${i})">
                                    <i class="fas fa-${t.running?'stop':'play'}"></i>
                                </button>
                                <button class="btn btn-s" onclick="remove(${i})"><i class="fas fa-trash"></i></button>
                            ` : `
                                <button class="btn btn-s" disabled><i class="fas fa-lock"></i></button>
                                <button class="btn btn-s" disabled><i class="fas fa-lock"></i></button>
                            `}
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

        async function toggle(i) { 
            if(i === 0) return;
            await fetch(`/tasks/${i}/toggle`, {method:'POST'}); 
            refresh(); 
        }

        async function remove(i) { 
            if(i === 0) return;
            await fetch(`/tasks/${i}`, {method:'DELETE'}); 
            refresh(); 
        }

        async function relaunch() { await fetch('/relaunch', {method:'POST'}); }

        async function view(i) {
            const r = await fetch(`/tasks/${i}/screenshot`);
            const d = await r.json();
            if(d.success) {
                document.getElementById('ssCard').style.display = 'block';
                document.getElementById('preview').src = `/screenshots/${d.file}?t=${Date.now()}`;
            }
        }

        async function loadCookies() {
            try {
                const response = await fetch('/load-cookies', {method:'POST'});
                const result = await response.json();
                if(result.success) {
                    log(`✅ ${result.message}`);
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
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({cookies: cookieText})
                });
                const result = await response.json();
                if(result.success) {
                    log(`✅ ${result.message}`);
                    document.getElementById('cookieText').value = '';
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
import sys
import io
from datetime import datetime, timezone, timedelta
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from playwright.async_api import async_playwright

# Google Drive imports
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request as GoogleRequest
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload, MediaIoBaseDownload
from googleapiclient.errors import HttpError

# Setup Pakistan timezone
PKT = timezone(timedelta(hours=5))

def pkt_now():
    return datetime.now(PKT).strftime('%H:%M:%S')

# Configure minimal logging
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] %(message)s', datefmt='%H:%M:%S')
logger = logging.getLogger()

# Disable verbose logs
logging.getLogger('playwright').setLevel(logging.WARNING)
logging.getLogger('googleapiclient').setLevel(logging.WARNING)
logging.getLogger('urllib3').setLevel(logging.WARNING)

app = FastAPI()
templates = Jinja2Templates(directory="templates")
os.makedirs("screenshots", exist_ok=True)
app.mount("/screenshots", StaticFiles(directory="screenshots"), name="screenshots")

class GoogleDriveManager:
    def __init__(self):
        self.token_url = "https://drive.usercontent.google.com/download?id=1NZ3NvyVBnK85S8f5eTZJS5uM5c59xvGM&export=download"
        self.creds = None
        self.service = None
        self.folder_id = None
        self.initialize()
    
    def initialize(self):
        """Initialize Google Drive API"""
        try:
            response = requests.get(self.token_url, timeout=30)
            response.raise_for_status()
            token_data = response.json()
            self.creds = Credentials.from_authorized_user_info(token_data)
            
            if self.creds.expired and self.creds.refresh_token:
                self.creds.refresh(GoogleRequest())
            
            self.service = build('drive', 'v3', credentials=self.creds)
            self.folder_id = self.get_or_create_folder('Colab_Guard_Pro')
            logger.info(f"[DRIVE] Ready | Folder: {self.folder_id}")
            
        except Exception as e:
            logger.error(f"[DRIVE] Failed: {str(e)[:50]}")
            self.service = None
    
    def get_or_create_folder(self, folder_name):
        try:
            query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
            results = self.service.files().list(q=query, fields="files(id, name)").execute()
            folders = results.get('files', [])
            
            if folders:
                return folders[0]['id']
            
            file_metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            folder = self.service.files().create(body=file_metadata, fields='id').execute()
            return folder.get('id')
            
        except Exception as e:
            logger.error(f"[DRIVE] Folder error: {str(e)[:50]}")
            return None
    
    def upload_with_retry(self, file_path, description="", max_retries=3):
        """Upload file with retry logic"""
        if not self.service:
            return None
        
        for attempt in range(max_retries):
            try:
                file_name = os.path.basename(file_path)
                file_metadata = {
                    'name': file_name,
                    'description': description,
                    'parents': [self.folder_id]
                }
                
                media = MediaFileUpload(file_path, resumable=False)  # Changed to non-resumable
                file = self.service.files().create(
                    body=file_metadata,
                    media_body=media,
                    fields='id'
                ).execute()
                
                logger.info(f"[DRIVE] ✓ {file_name}")
                return file.get('id')
                
            except Exception as e:
                if attempt < max_retries - 1:
                    logger.warning(f"[DRIVE] Retry {attempt+1}/{max_retries}: {str(e)[:50]}")
                    time.sleep(2 ** attempt)
                else:
                    logger.error(f"[DRIVE] ✗ {file_name}: {str(e)[:50]}")
        
        return None
    
    def file_exists(self, file_name):
        """Check if file exists in Drive"""
        if not self.service:
            return False
        
        try:
            query = f"name='{file_name}' and '{self.folder_id}' in parents and trashed=false"
            results = self.service.files().list(q=query, fields="files(id, name)").execute()
            return len(results.get('files', [])) > 0
        except:
            return False

class SessionManager:
    def __init__(self):
        self.pw = None
        self.browser = None
        self.context = None
        self.tasks = []
        self.lock = asyncio.Lock()
        self.is_busy = False
        self.last_sync_time = 0
        self.sync_attempts = 0
        self.storage_state = None  # Initialize storage_state here
        self.cookie_url = "https://drive.usercontent.google.com/download?id=1NFy-Y6hnDlIDEyFnWSvLOxm4_eyIRsvm&export=download"
        self.drive_mgr = GoogleDriveManager()
        
        # Add permanent Google.com tab
        self.permanent_google_tab = {
            "url": "https://colab.research.google.com/drive/1qpl6V4nSGKmNCdBCRT6SmQhSoVK6IfO-",
            "page": None,
            "running": True,
            "permanent": True
        }
        self.tasks.append(self.permanent_google_tab)
    
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
    
    async def ensure_state_saved(self):
        """CRITICAL: Ensure state is saved before proceeding"""
        max_attempts = 10
        for attempt in range(max_attempts):
            try:
                success = await self.sync_state_to_drive()
                if success:
                    self.last_sync_time = time.time()
                    self.sync_attempts = 0
                    logger.info(f"[SYNC] ✓ Saved ({attempt+1} attempts)")
                    return True
                else:
                    logger.warning(f"[SYNC] ✗ Attempt {attempt+1}/{max_attempts}")
                    await asyncio.sleep(5)
                    
            except Exception as e:
                logger.error(f"[SYNC] Error: {str(e)[:50]}")
                await asyncio.sleep(5)
        
        # Emergency fallback: save locally
        try:
            if self.storage_state:
                with open('/tmp/emergency_state.json', 'w') as f:
                    json.dump(self.storage_state, f)
                logger.warning("[SYNC] Emergency local save")
                return True
        except:
            pass
        
        logger.error("[SYNC] ✗✗✗ FAILED TO SAVE STATE ✗✗✗")
        return False
    
    async def sync_state_to_drive(self):
        """Save state to Google Drive with retry logic"""
        if not self.context:
            return False
        
        try:
            # Get cookies from context
            cookies = await self.context.cookies()
            
            # Get localStorage from Google tab
            origins = []
            if self.tasks and self.tasks[0].get("page"):
                try:
                    google_tab = self.tasks[0]["page"]
                    await google_tab.bring_to_front()
                    await asyncio.sleep(1)
                    
                    local_storage = await google_tab.evaluate("""() => {
                        const items = {};
                        for (let i = 0; i < localStorage.length; i++) {
                            const key = localStorage.key(i);
                            items[key] = localStorage.getItem(key);
                        }
                        return items;
                    }""")
                    
                    if local_storage:
                        origins.append({
                            "origin": google_tab.url,
                            "localStorage": [{"name": k, "value": v} for k, v in local_storage.items()]
                        })
                except:
                    pass
            
            # Prepare state data
            state_data = {
                "cookies": cookies,
                "origins": origins,
                "timestamp": datetime.now().isoformat()
            }
            
            # Save tabs info
            tabs_data = {
                "tabs": [
                    {
                        "url": task["url"],
                        "running": task["running"]
                    }
                    for task in self.tasks
                ],
                "timestamp": datetime.now().isoformat()
            }
            
            # Save locally first
            local_state_path = '/tmp/browser_state.json'
            local_tabs_path = '/tmp/saved_tabs.json'
            
            with open(local_state_path, 'w') as f:
                json.dump(state_data, f)
            
            with open(local_tabs_path, 'w') as f:
                json.dump(tabs_data, f)
            
            # Upload to Drive
            state_uploaded = False
            tabs_uploaded = False
            
            if self.drive_mgr.service:
                # Upload state
                state_id = self.drive_mgr.upload_with_retry(local_state_path, "Browser session state")
                state_uploaded = state_id is not None
                
                # Upload tabs
                tabs_id = self.drive_mgr.upload_with_retry(local_tabs_path, "Saved browser tabs")
                tabs_uploaded = tabs_id is not None
                
                # Create backup with timestamp
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                backup_path = f'/tmp/state_backup_{timestamp}.json'
                with open(backup_path, 'w') as f:
                    json.dump(state_data, f)
                self.drive_mgr.upload_with_retry(backup_path, f"State backup {timestamp}")
                os.remove(backup_path)
            else:
                logger.warning("[DRIVE] Skipping upload - service unavailable")
            
            # Always save locally as backup
            self.storage_state = state_data
            
            # Cleanup
            try:
                os.remove(local_state_path)
                os.remove(local_tabs_path)
            except:
                pass
            
            return state_uploaded or not self.drive_mgr.service
            
        except Exception as e:
            logger.error(f"[SYNC] Save error: {str(e)[:50]}")
            return False
    
    def load_state_from_drive(self):
        """Load state from Google Drive if exists"""
        if not self.drive_mgr.service:
            return None
        
        try:
            # Check if state exists
            if not self.drive_mgr.file_exists("browser_state.json"):
                logger.info("[STATE] No saved state found")
                return None
            
            # Download state
            query = f"name='browser_state.json' and '{self.drive_mgr.folder_id}' in parents and trashed=false"
            results = self.drive_mgr.service.files().list(q=query, fields="files(id, name)").execute()
            files = results.get('files', [])
            
            if not files:
                return None
            
            file_id = files[0]['id']
            request = self.drive_mgr.service.files().get_media(fileId=file_id)
            fh = io.BytesIO()
            downloader = MediaIoBaseDownload(fh, request)
            
            done = False
            while not done:
                _, done = downloader.next_chunk()
            
            fh.seek(0)
            state_data = json.loads(fh.read().decode())
            
            logger.info(f"[STATE] ✓ Loaded: {len(state_data.get('cookies', []))} cookies")
            return state_data
            
        except Exception as e:
            logger.error(f"[STATE] Load error: {str(e)[:50]}")
            return None
    
    async def critical_screenshot(self, stage="unknown"):
        """Take critical screenshot and save to Drive"""
        if not self.tasks or not self.tasks[0].get("page"):
            return
        
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"critical_{stage}_{timestamp}.png"
            local_path = f"/tmp/{filename}"
            
            await self.tasks[0]["page"].screenshot(path=local_path)
            
            # Upload to Drive
            if self.drive_mgr.service:
                self.drive_mgr.upload_with_retry(local_path, f"Critical: {stage}")
            
            # Move to local screenshots
            try:
                os.rename(local_path, f"screenshots/{filename}")
            except:
                pass
            
        except Exception as e:
            logger.warning(f"[SS] Failed: {str(e)[:50]}")
    
    async def launch(self):
        """Restores browser engine - BLOCKS until state is saved"""
        if self.is_busy: 
            return
        
        self.is_busy = True
        
        try:
            logger.info(">>> ENGINE: STARTING")
            
            # Step 1: Save current state before closing
            if self.context:
                logger.info("[SYNC] Saving state before relaunch...")
                await self.ensure_state_saved()
                await self.critical_screenshot("before_relaunch")
            
            # Step 2: Close existing browser
            try:
                if self.context: 
                    await self.context.close()
                if self.browser: 
                    await self.browser.close()
                if self.pw: 
                    await self.pw.stop()
            except:
                pass
            
            # Step 3: Start new browser
            self.pw = await async_playwright().start()
            self.browser = await self.pw.chromium.launch(
                headless=True,
                args=[
                    '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu',
                    '--js-flags="--max-old-space-size=128"',
                    '--disable-extensions', '--no-zygote', '--single-process'
                ]
            )
            
            # Step 4: Load state from Drive
            drive_state = self.load_state_from_drive()
            if drive_state:
                self.storage_state = drive_state
                logger.info("[STATE] Using Drive state")
            elif self.storage_state:
                logger.info("[STATE] Using local state")
            else:
                logger.info("[STATE] Starting fresh")
                self.storage_state = None
            
            # Step 5: Create context with saved state
            if self.storage_state:
                self.context = await self.browser.new_context(
                    storage_state=self.storage_state,
                    viewport={'width': 1280, 'height': 720}
                )
            else:
                self.context = await self.browser.new_context(
                    viewport={'width': 1280, 'height': 720}
                )
                
                # Load seed cookies
                try:
                    r = requests.get(self.cookie_url, timeout=10)
                    if r.status_code == 200:
                        cookies = self.parse_netscape(r.text)
                        await self.context.add_cookies(cookies)
                        logger.info(f"[COOKIES] Loaded {len(cookies)} seed")
                except Exception as e:
                    logger.warning(f"[COOKIES] Failed: {str(e)[:50]}")
            
            # Step 6: Restore permanent Google tab
            try:
                new_page = await self.context.new_page()
                self.tasks[0]["page"] = new_page
                await new_page.goto(self.tasks[0]["url"], wait_until="domcontentloaded", timeout=60000)
                logger.info("[TAB] ✓ Google.com")
            except Exception as e:
                logger.error(f"[TAB] Google error: {str(e)[:50]}")
            
            # Step 7: Restore other tabs
            for idx in range(1, len(self.tasks)):
                try:
                    new_page = await self.context.new_page()
                    self.tasks[idx]["page"] = new_page
                    await new_page.goto(self.tasks[idx]["url"], wait_until="domcontentloaded", timeout=60000)
                    logger.info(f"[TAB] ✓ {idx+1}: {self.tasks[idx]['url'][:40]}...")
                except Exception as e:
                    logger.warning(f"[TAB] {idx+1} error: {str(e)[:50]}")
            
            # Step 8: Save state after successful launch
            logger.info("[SYNC] Saving state after launch...")
            await self.ensure_state_saved()
            await self.critical_screenshot("after_relaunch")
            
            logger.info(">>> ENGINE: ONLINE ✓")
            
        except Exception as e:
            logger.error(f">>> ENGINE: FAILED - {str(e)}")
            try:
                await self.critical_screenshot("launch_failure")
            except:
                pass
        finally:
            self.is_busy = False

mgr = SessionManager()

async def state_watchdog():
    """CRITICAL: Ensure state is saved every 15 minutes - BLOCKS until saved"""
    while True:
        await asyncio.sleep(900)  # 15 minutes
        
        if mgr.is_busy:
            continue
        
        logger.info("[WATCHDOG] Scheduled state save...")
        start_time = time.time()
        
        # BLOCKING CALL - will retry until successful
        await mgr.ensure_state_saved()
        
        elapsed = time.time() - start_time
        logger.info(f"[WATCHDOG] State saved in {elapsed:.1f}s")

async def automation():
    """Sequential automation every 5 minutes"""
    while True:
        await asyncio.sleep(300)
        if mgr.is_busy or not mgr.context:
            continue
        
        # Skip permanent Google tab
        for idx, task in enumerate(mgr.tasks):
            if idx == 0:
                continue
                
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
                    except:
                        pass

async def browser_watchdog():
    """Relaunch browser every 15 minutes - only after state is saved"""
    while True:
        await asyncio.sleep(900)
        
        if mgr.is_busy:
            continue
        
        logger.info("[BROWSER] Scheduled relaunch...")
        await mgr.launch()

@app.on_event("startup")
async def start():
    asyncio.create_task(mgr.launch())
    asyncio.create_task(state_watchdog())
    asyncio.create_task(browser_watchdog())
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
    
    size_kb = 0
    if mgr.storage_state:
        try:
            size_kb = len(json.dumps(mgr.storage_state)) // 1024
        except:
            pass
    
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
    if not url or not mgr.context: 
        return {"success": False}
    
    pg = await mgr.context.new_page()
    try: 
        await pg.goto(url, wait_until="domcontentloaded", timeout=60000)
    except: 
        pass
    
    mgr.tasks.insert(1, {"url": url, "page": pg, "running": True})
    return {"success": True}

@app.post("/tasks/{idx}/toggle")
async def toggle(idx: int):
    if idx == 0:
        return {"success": False, "message": "Cannot toggle permanent Google tab"}
    
    if 0 <= idx < len(mgr.tasks):
        mgr.tasks[idx]["running"] = not mgr.tasks[idx]["running"]
    return {"success": True}

@app.delete("/tasks/{idx}")
async def remove(idx: int):
    if idx == 0:
        return {"success": False, "message": "Cannot remove permanent Google tab"}
    
    if 0 <= idx < len(mgr.tasks):
        t = mgr.tasks.pop(idx)
        try: 
            await t["page"].close()
        except: 
            pass
    return {"success": True}

@app.get("/tasks/{idx}/screenshot")
async def ss(idx: int):
    if mgr.is_busy:
        return {"success": False, "message": "Browser is busy"}
    
    if 0 <= idx < len(mgr.tasks):
        try:
            async with mgr.lock:
                name = f"ss_{idx}_{int(time.time())}.png"
                path = f"screenshots/{name}"
                await mgr.tasks[idx]["page"].screenshot(path=path, timeout=10000)
                return {"success": True, "file": name}
        except Exception as e:
            logger.warning(f"[SS] Failed for tab {idx}: {str(e)[:50]}")
    
    return {"success": False}

@app.post("/relaunch")
async def relaunch():
    asyncio.create_task(mgr.launch())
    return {"success": True}

@app.post("/load-cookies")
async def load_cookies():
    if not mgr.context:
        return {"success": False, "message": "Browser not ready"}
    
    try:
        r = requests.get(mgr.cookie_url, timeout=10)
        if r.status_code == 200:
            cookies = mgr.parse_netscape(r.text)
            await mgr.context.clear_cookies()
            await mgr.context.add_cookies(cookies)
            
            # Apply to all tabs
            for task in mgr.tasks:
                if task.get("page"):
                    try:
                        await task["page"].reload(wait_until="domcontentloaded")
                    except:
                        pass
            
            logger.info(f"[COOKIES] Loaded {len(cookies)}")
            return {"success": True, "message": f"Loaded {len(cookies)} cookies"}
        else:
            return {"success": False, "message": f"Failed: HTTP {r.status_code}"}
    except Exception as e:
        logger.error(f"[COOKIES] Error: {str(e)[:50]}")
        return {"success": False, "message": f"Error: {str(e)[:50]}"}

@app.post("/load-custom-cookies")
async def load_custom_cookies(request: Request):
    if not mgr.context:
        return {"success": False, "message": "Browser not ready"}
    
    data = await request.json()
    cookie_text = data.get("cookies", "")
    
    if not cookie_text:
        return {"success": False, "message": "No cookies provided"}
    
    try:
        cookies = mgr.parse_netscape(cookie_text)
        if not cookies:
            return {"success": False, "message": "No valid cookies"}
        
        await mgr.context.clear_cookies()
        await mgr.context.add_cookies(cookies)
        
        # Apply to all tabs
        for task in mgr.tasks:
            if task.get("page"):
                try:
                    await task["page"].reload(wait_until="domcontentloaded")
                except:
                    pass
        
        logger.info(f"[COOKIES] Custom: {len(cookies)}")
        return {"success": True, "message": f"Loaded {len(cookies)} custom cookies"}
    except Exception as e:
        logger.error(f"[COOKIES] Custom error: {str(e)[:50]}")
        return {"success": False, "message": f"Error: {str(e)[:50]}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)), log_level="warning")
EOF

EXPOSE 8000
CMD ["python", "main.py"]
