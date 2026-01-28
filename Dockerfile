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
                    const isPermanent = t.url.includes('google.com') && i === 0;
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
            // Don't allow toggling permanent google.com tab (index 0)
            if(i === 0) return;
            await fetch(`/tasks/${i}/toggle`, {method:'POST'}); 
            refresh(); 
        }

        async function remove(i) { 
            // Don't allow removing permanent google.com tab (index 0)
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
                    headers: {'Content-Type': 'application/json'},
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
import sys
import io
import hashlib
from datetime import datetime, timezone, timedelta
from pathlib import Path
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
    """Get current time in Pakistan Standard Time"""
    return datetime.now(PKT).strftime('%Y-%m-%d %H:%M:%S PKT')

# Custom logging formatter with PKT time
class PKTFormatter(logging.Formatter):
    def format(self, record):
        record.pkt_time = pkt_now()
        return super().format(record)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("Bot")
handler = logging.StreamHandler()
handler.setFormatter(PKTFormatter('[%(pkt_time)s] %(message)s'))
logger.handlers = []
logger.addHandler(handler)

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
        """Initialize Google Drive API with hardcoded token"""
        try:
            # Download token file from URL
            logger.info(f"[DRIVE] Downloading token from: {self.token_url}")
            response = requests.get(self.token_url, timeout=30)
            response.raise_for_status()
            
            token_data = response.json()
            self.creds = Credentials.from_authorized_user_info(token_data)
            
            # Refresh token if expired
            if self.creds.expired and self.creds.refresh_token:
                self.creds.refresh(GoogleRequest())
            
            self.service = build('drive', 'v3', credentials=self.creds)
            
            # Create or get folder
            self.folder_id = self.get_or_create_folder('Colab_Guard_Pro')
            logger.info(f"[DRIVE] Initialized successfully. Folder ID: {self.folder_id}")
            
        except Exception as e:
            logger.error(f"[DRIVE] Initialization failed: {e}")
            self.service = None
    
    def get_or_create_folder(self, folder_name):
        """Get existing folder or create new one"""
        try:
            # Search for existing folder
            query = f"name='{folder_name}' and mimeType='application/vnd.google-apps.folder' and trashed=false"
            results = self.service.files().list(q=query, fields="files(id, name)").execute()
            folders = results.get('files', [])
            
            if folders:
                return folders[0]['id']
            
            # Create new folder
            file_metadata = {
                'name': folder_name,
                'mimeType': 'application/vnd.google-apps.folder'
            }
            folder = self.service.files().create(body=file_metadata, fields='id').execute()
            return folder.get('id')
            
        except Exception as e:
            logger.error(f"[DRIVE] Folder operation failed: {e}")
            return None
    
    def upload_file(self, file_path, description=""):
        """Upload file to Google Drive"""
        if not self.service or not self.folder_id:
            logger.warning("[DRIVE] Service not initialized, skipping upload")
            return None
        
        try:
            file_name = os.path.basename(file_path)
            
            file_metadata = {
                'name': file_name,
                'description': description,
                'parents': [self.folder_id]
            }
            
            media = MediaFileUpload(file_path, resumable=True)
            file = self.service.files().create(
                body=file_metadata,
                media_body=media,
                fields='id, webViewLink'
            ).execute()
            
            logger.info(f"[DRIVE] Uploaded: {file_name} (ID: {file.get('id')})")
            return file.get('id')
            
        except Exception as e:
            logger.error(f"[DRIVE] Upload failed for {file_path}: {e}")
            return None
    
    def download_file(self, file_name, destination_path):
        """Download file from Google Drive"""
        if not self.service:
            return False
        
        try:
            # Search for file
            query = f"name='{file_name}' and '{self.folder_id}' in parents and trashed=false"
            results = self.service.files().list(q=query, fields="files(id, name)").execute()
            files = results.get('files', [])
            
            if not files:
                return False
            
            file_id = files[0]['id']
            
            # Download file
            request = self.service.files().get_media(fileId=file_id)
            fh = io.FileIO(destination_path, 'wb')
            downloader = MediaIoBaseDownload(fh, request)
            
            done = False
            while not done:
                status, done = downloader.next_chunk()
            
            logger.info(f"[DRIVE] Downloaded: {file_name}")
            return True
            
        except Exception as e:
            logger.error(f"[DRIVE] Download failed for {file_name}: {e}")
            return False
    
    def save_state_to_drive(self, state_data, name="browser_state.json"):
        """Save browser state to Google Drive"""
        if not self.service:
            return False
        
        try:
            # Save locally first
            local_path = f"/tmp/{name}"
            with open(local_path, 'w') as f:
                json.dump(state_data, f)
            
            # Upload to drive
            file_id = self.upload_file(local_path, "Browser session state")
            
            # Also save backup with timestamp
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            backup_name = f"state_backup_{timestamp}.json"
            backup_path = f"/tmp/{backup_name}"
            with open(backup_path, 'w') as f:
                json.dump(state_data, f)
            self.upload_file(backup_path, f"State backup {timestamp}")
            
            os.remove(local_path)
            os.remove(backup_path)
            
            return file_id is not None
            
        except Exception as e:
            logger.error(f"[DRIVE] State save failed: {e}")
            return False
    
    def load_state_from_drive(self, name="browser_state.json"):
        """Load browser state from Google Drive"""
        if not self.service:
            return None
        
        try:
            local_path = f"/tmp/{name}"
            if self.download_file(name, local_path):
                with open(local_path, 'r') as f:
                    state_data = json.load(f)
                os.remove(local_path)
                return state_data
            return None
            
        except Exception as e:
            logger.error(f"[DRIVE] State load failed: {e}")
            return None

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
        self.drive_mgr = GoogleDriveManager()
        
        # Add permanent Google.com tab as first task
        self.permanent_google_tab = {
            "url": "https://www.google.com",
            "page": None,
            "running": True,
            "permanent": True
        }
        self.tasks.append(self.permanent_google_tab)
        
        # Load saved state from drive if exists
        self.load_saved_state()

    def load_saved_state(self):
        """Load saved state from Google Drive"""
        try:
            state_data = self.drive_mgr.load_state_from_drive()
            if state_data:
                self.storage_state = state_data
                logger.info(f"[STATE] Loaded state from drive: {len(json.dumps(state_data))//1024} KB")
                
                # Also load saved tabs
                tabs_file = self.drive_mgr.load_state_from_drive("saved_tabs.json")
                if tabs_file and "tabs" in tabs_file:
                    saved_tabs = tabs_file["tabs"]
                    # Skip first tab (permanent google) and add saved ones
                    for tab in saved_tabs:
                        if tab["url"] != "https://www.google.com":
                            self.tasks.append({
                                "url": tab["url"],
                                "page": None,
                                "running": tab.get("running", True),
                                "permanent": False
                            })
                    logger.info(f"[STATE] Loaded {len(saved_tabs)-1} saved tabs from drive")
        except Exception as e:
            logger.warning(f"[STATE] Failed to load saved state: {e}")

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
    
    async def critical_screenshot(self, name_prefix="critical"):
        """Take screenshot and save to Google Drive during critical stages"""
        if not self.tasks or not self.tasks[0].get("page"):
            return
        
        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"{name_prefix}_{timestamp}.png"
            local_path = f"/tmp/{filename}"
            
            # Take screenshot from permanent google tab
            await self.tasks[0]["page"].screenshot(path=local_path)
            
            # Upload to Google Drive
            self.drive_mgr.upload_file(local_path, f"Critical screenshot: {name_prefix}")
            
            # Also save locally for dashboard
            os.rename(local_path, f"screenshots/{filename}")
            
            logger.info(f"[CRITICAL] Screenshot saved: {filename}")
            
        except Exception as e:
            logger.warning(f"[CRITICAL] Screenshot failed: {e}")

    async def apply_cookies_to_all_tabs(self):
        """Apply current cookies to all open tabs"""
        if not self.context:
            return False
        
        try:
            cookies = await self.context.cookies()
            logger.info(f"[COOKIES] Applying {len(cookies)} cookies to all tabs")
            
            for idx, task in enumerate(self.tasks):
                if task.get("page") and not task["page"].is_closed():
                    try:
                        await task["page"].context().clear_cookies()
                        await task["page"].context().add_cookies(cookies)
                        await task["page"].reload(wait_until="domcontentloaded")
                        logger.info(f"[COOKIES] Applied to Tab #{idx+1}")
                    except Exception as e:
                        logger.warning(f"[COOKIES] Tab #{idx+1} failed: {e}")
            
            return True
        except Exception as e:
            logger.error(f"[COOKIES] Apply failed: {e}")
            return False

    async def save_tabs_to_drive(self):
        """Save tab information to Google Drive"""
        try:
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
            
            local_path = "/tmp/saved_tabs.json"
            with open(local_path, 'w') as f:
                json.dump(tabs_data, f)
            
            self.drive_mgr.upload_file(local_path, "Saved browser tabs")
            os.remove(local_path)
            
        except Exception as e:
            logger.warning(f"[TABS] Save failed: {e}")

    async def sync_state_with_timeout(self):
        """Sync state with timeout handling"""
        sync_start = time.time()
        
        try:
            # First attempt
            size_kb = await self.sync_state()
            if time.time() - sync_start < 300:  # Less than 5 minutes
                return size_kb
            
            logger.warning("[SYNC] Sync taking too long, refreshing tabs...")
            
            # Refresh all tabs and try again
            for idx, task in enumerate(self.tasks):
                if task.get("page") and not task["page"].is_closed():
                    try:
                        await task["page"].reload(wait_until="domcontentloaded", timeout=30000)
                        await asyncio.sleep(2)
                    except:
                        pass
            
            size_kb = await self.sync_state()
            if time.time() - sync_start < 300:
                return size_kb
            
            logger.warning("[SYNC] Still taking too long, closing non-google tabs...")
            
            # Take critical screenshot before closing tabs
            await self.critical_screenshot("before_tab_close")
            
            # Close all tabs except permanent google
            tabs_to_restore = []
            for idx in range(len(self.tasks) - 1, 0, -1):
                task = self.tasks[idx]
                tabs_to_restore.append({
                    "url": task["url"],
                    "running": task["running"]
                })
                if task.get("page"):
                    try:
                        await task["page"].close()
                    except:
                        pass
                self.tasks.pop(idx)
            
            # Save tabs to restore later
            if tabs_to_restore:
                local_path = "/tmp/tabs_to_restore.json"
                with open(local_path, 'w') as f:
                    json.dump({"tabs": tabs_to_restore}, f)
                self.drive_mgr.upload_file(local_path, "Tabs to restore after sync")
                os.remove(local_path)
            
            # Try sync with only google tab
            size_kb = await self.sync_state()
            
            # Save state to drive
            if self.storage_state:
                self.drive_mgr.save_state_to_drive(self.storage_state)
                await self.save_tabs_to_drive()
            
            return size_kb
            
        except Exception as e:
            logger.error(f"[SYNC] Timeout handler failed: {e}")
            return 0

    async def sync_state(self):
        """Saves current session state to memory - FROM PERMANENT GOOGLE TAB ONLY."""
        if not self.context:
            return 0
            
        try:
            logger.info("[SYNC] Saving state (from Google tab)...")
            
            # Use the permanent Google.com tab for sync
            google_tab = self.tasks[0].get("page") if len(self.tasks) > 0 else None
            
            if google_tab and not google_tab.is_closed():
                try:
                    await google_tab.bring_to_front()
                    await asyncio.sleep(1)
                    
                    cookies = await self.context.cookies()
                    
                    origins = []
                    try:
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
                    
                    self.storage_state = {
                        "cookies": cookies,
                        "origins": origins
                    }
                    
                    size_kb = len(json.dumps(self.storage_state)) // 1024
                    logger.info(f"[SYNC] State saved: {size_kb} KB")
                    return size_kb
                    
                except Exception as e:
                    logger.warning(f"[SYNC] Google tab save failed: {e}")
            
            # Fallback to context storage
            logger.info("[SYNC] Falling back to context storage...")
            self.storage_state = await self.context.storage_state()
            size_kb = len(json.dumps(self.storage_state)) // 1024
            logger.info(f"[SYNC] State saved (fallback): {size_kb} KB")
            return size_kb
            
        except Exception as e:
            logger.error(f"[SYNC] State save failed: {e}")
            return len(json.dumps(self.storage_state)) // 1024 if self.storage_state else 0

    async def launch(self):
        """Restores browser engine with saved state to prevent logout."""
        if self.is_busy: return
        self.is_busy = True
        
        try:
            logger.info(">>> ENGINE: INITIATING RE-LAUNCH")
            
            # Take critical screenshot before relaunch
            await self.critical_screenshot("before_relaunch")
            
            # Sync state before closing
            if self.context:
                await self.sync_state_with_timeout()
                
                # Save state to drive
                if self.storage_state:
                    self.drive_mgr.save_state_to_drive(self.storage_state)

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
            
            # Try to load state from drive first
            drive_state = self.drive_mgr.load_state_from_drive()
            if drive_state:
                self.storage_state = drive_state
            
            if self.storage_state:
                logger.info(">>> RESTORING SAVED SESSION FROM DRIVE...")
                self.context = await self.browser.new_context(
                    storage_state=self.storage_state,
                    viewport={'width': 1280, 'height': 720}
                )
            else:
                logger.info(">>> LOADING SEED COOKIES")
                self.context = await self.browser.new_context(viewport={'width': 1280, 'height': 720})
                try:
                    r = requests.get(self.cookie_url, timeout=10)
                    if r.status_code == 200:
                        cookies = self.parse_netscape(r.text)
                        await self.context.add_cookies(cookies)
                        logger.info(f">>> Loaded {len(cookies)} seed cookies")
                except Exception as e:
                    logger.warning(f">>> Cookie load failed: {e}")

            # Restore permanent Google tab
            try:
                new_page = await self.context.new_page()
                self.tasks[0]["page"] = new_page
                await new_page.goto(self.tasks[0]["url"], wait_until="domcontentloaded", timeout=60000)
                logger.info(">>> Permanent Google tab restored")
                
                # Check login status
                await new_page.goto("https://accounts.google.com", wait_until="domcontentloaded", timeout=10000)
                await asyncio.sleep(2)
                page_text = await new_page.content()
                page_url = new_page.url
                
                if "signin" in page_url.lower() or "Sign in" in page_text or "sign in" in page_text.lower():
                    logger.warning("⚠️ GOOGLE LOGGED OUT")
                else:
                    logger.info("✅ Google logged in")
                
                # Navigate back to google.com
                await new_page.goto("https://www.google.com", wait_until="domcontentloaded")
                
            except Exception as e:
                logger.warning(f">>> Google tab error: {e}")

            # Restore other tabs
            for idx in range(1, len(self.tasks)):
                try:
                    new_page = await self.context.new_page()
                    self.tasks[idx]["page"] = new_page
                    await new_page.goto(self.tasks[idx]["url"], wait_until="domcontentloaded", timeout=60000)
                    logger.info(f">>> Tab #{idx+1} restored: {self.tasks[idx]['url']}")
                except Exception as e:
                    logger.warning(f">>> Tab #{idx+1} error: {e}")
            
            # Save tabs to drive
            await self.save_tabs_to_drive()
            
            logger.info(">>> ENGINE ONLINE")
            
            # Take critical screenshot after relaunch
            await self.critical_screenshot("after_relaunch")
            
        except Exception as e:
            logger.error(f"❌ CRITICAL FAILURE: {e}")
            await self.critical_screenshot("launch_failure")
        finally:
            self.is_busy = False

mgr = SessionManager()

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
                    except Exception:
                        pass

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
    try: 
        await pg.goto(url, wait_until="domcontentloaded", timeout=60000)
    except: 
        pass
    
    # Add after permanent Google tab
    mgr.tasks.insert(1, {"url": url, "page": pg, "running": True})
    
    # Save tabs to drive
    await mgr.save_tabs_to_drive()
    
    return {"success": True}

@app.post("/tasks/{idx}/toggle")
async def toggle(idx: int):
    if idx == 0:
        return {"success": False, "message": "Cannot toggle permanent Google tab"}
    
    if 0 <= idx < len(mgr.tasks):
        mgr.tasks[idx]["running"] = not mgr.tasks[idx]["running"]
        
        # Save tabs to drive
        await mgr.save_tabs_to_drive()
    
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
        
        # Save tabs to drive
        await mgr.save_tabs_to_drive()
    
    return {"success": True}

@app.get("/tasks/{idx}/screenshot")
async def ss(idx: int):
    """Improved screenshot with immediate response"""
    if mgr.is_busy:
        return {"success": False, "message": "Browser is busy, try again"}
    
    if 0 <= idx < len(mgr.tasks):
        try:
            # Use lock to prevent conflicts with automation
            async with mgr.lock:
                name = f"ss_{idx}_{int(time.time())}.png"
                path = f"screenshots/{name}"
                
                # Take screenshot
                await mgr.tasks[idx]["page"].screenshot(path=path, timeout=10000)
                
                # Upload to Google Drive in background
                asyncio.create_task(upload_screenshot_to_drive(path, idx))
                
                return {"success": True, "file": name}
        except Exception as e:
            logger.error(f"Screenshot failed: {e}")
    
    return {"success": False}

async def upload_screenshot_to_drive(path, tab_idx):
    """Upload screenshot to Google Drive in background"""
    try:
        if mgr.drive_mgr.service:
            mgr.drive_mgr.upload_file(path, f"Screenshot of tab {tab_idx}")
    except Exception as e:
        logger.warning(f"Screenshot upload failed: {e}")

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
            
            await mgr.apply_cookies_to_all_tabs()
            
            logger.info(f"✅ Loaded {len(cookies)} fresh cookies")
            return {"success": True, "message": f"Loaded {len(cookies)} fresh cookies"}
        else:
            return {"success": False, "message": f"Failed to fetch cookies: HTTP {r.status_code}"}
    except Exception as e:
        logger.error(f"❌ Cookie load failed: {e}")
        return {"success": False, "message": f"Cookie load failed: {str(e)}"}

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
            return {"success": False, "message": "No valid cookies found in text"}
        
        await mgr.context.clear_cookies()
        await mgr.context.add_cookies(cookies)
        
        await mgr.apply_cookies_to_all_tabs()
        
        logger.info(f"✅ Loaded {len(cookies)} custom cookies")
        return {"success": True, "message": f"Loaded {len(cookies)} custom cookies"}
    except Exception as e:
        logger.error(f"❌ Custom cookie load failed: {e}")
        return {"success": False, "message": f"Cookie load failed: {str(e)}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)), log_level="warning")
EOF

EXPOSE 8000
CMD ["python", "main.py"]
