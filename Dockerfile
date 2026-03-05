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
                    <h3><i class="fas fa-microchip"></i> Active Tabs <span style="font-size:11px; color:#94a3b8">(Primary Colab is permanent first tab)</span></h3>
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
                    const isPermanent = i === 0;
                    item.innerHTML = `
                        <div style="flex:1">
                            <div style="display:flex; align-items:center">
                                <div style="font-size:11px; color:${t.running?'#4ade80':'#94a3b8'}">
                                    ${t.running?'● RUNNING':'● STOPPED'}
                                </div>
                                ${isPermanent ? '<span class="permanent-tag">PRIMARY</span>' : ''}
                            </div>
                            <div class="task-url">${t.url}</div>
                        </div>
                        <div style="display:flex; gap:5px">
                            <button class="btn btn-s" onclick="view(${i})"><i class="fas fa-eye"></i></button>
                            <button class="btn ${t.running?'btn-d':'btn-p'}" onclick="toggle(${i})">
                                <i class="fas fa-${t.running?'stop':'play'}"></i>
                            </button>
                            ${!isPermanent ? `
                                <button class="btn btn-s" onclick="remove(${i})"><i class="fas fa-trash"></i></button>
                            ` : `
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

# --- BACKEND SYSTEM WITH IMPROVED STABILITY ---
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
import traceback
from datetime import datetime, timezone, timedelta
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from playwright.async_api import async_playwright, Error as PlaywrightError

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

# Configure logging with file output for debugging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(message)s',
    datefmt='%H:%M:%S',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/tmp/colab_guard.log')
    ]
)
logger = logging.getLogger()

# Disable verbose logs
logging.getLogger('playwright').setLevel(logging.WARNING)
logging.getLogger('googleapiclient').setLevel(logging.WARNING)
logging.getLogger('urllib3').setLevel(logging.WARNING)
logging.getLogger('google.auth').setLevel(logging.WARNING)

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
        self.last_upload_cleanup = 0
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
            
            self.service = build('drive', 'v3', credentials=self.creds, cache_discovery=False)
            self.folder_id = self.get_or_create_folder('Colab_Guard_Pro')
            logger.info(f"[DRIVE] Ready | Folder: {self.folder_id}")
            
        except Exception as e:
            logger.error(f"[DRIVE] Failed: {str(e)[:100]}")
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
            logger.error(f"[DRIVE] Folder error: {str(e)[:100]}")
            return None
    
    def cleanup_old_backups(self, max_backups=10):
        """Keep only the most recent backups"""
        if not self.service:
            return
        
        try:
            # Only cleanup every hour
            if time.time() - self.last_upload_cleanup < 3600:
                return
            
            query = f"name contains 'state_backup_' and '{self.folder_id}' in parents and trashed=false"
            results = self.service.files().list(
                q=query, 
                fields="files(id, name, createdTime)",
                orderBy="createdTime desc"
            ).execute()
            
            files = results.get('files', [])
            
            # Delete old backups beyond max_backups
            if len(files) > max_backups:
                for file in files[max_backups:]:
                    try:
                        self.service.files().delete(fileId=file['id']).execute()
                        logger.debug(f"[DRIVE] Cleaned old backup: {file['name']}")
                    except:
                        pass
            
            self.last_upload_cleanup = time.time()
            
        except Exception as e:
            logger.warning(f"[DRIVE] Cleanup error: {str(e)[:100]}")
    
    def upload_with_retry(self, file_path, description="", max_retries=2):
        """Upload file with retry logic"""
        if not self.service:
            return None
        
        # Clean up old backups occasionally
        self.cleanup_old_backups()
        
        for attempt in range(max_retries):
            try:
                file_name = os.path.basename(file_path)
                file_metadata = {
                    'name': file_name,
                    'description': description,
                    'parents': [self.folder_id]
                }
                
                media = MediaFileUpload(file_path, resumable=False)
                file = self.service.files().create(
                    body=file_metadata,
                    media_body=media,
                    fields='id'
                ).execute()
                
                logger.info(f"[DRIVE] ✓ {file_name}")
                return file.get('id')
                
            except (HttpError, BrokenPipeError, ConnectionError) as e:
                if attempt < max_retries - 1:
                    logger.warning(f"[DRIVE] Retry {attempt+1}/{max_retries}")
                    time.sleep(2)
                else:
                    logger.error(f"[DRIVE] ✗ {file_name}: {str(e)[:100]}")
            except Exception as e:
                logger.error(f"[DRIVE] ✗ {file_name}: {str(e)[:100]}")
                break
        
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
        self.storage_state = None
        self.cookie_url = "https://drive.usercontent.google.com/download?id=1NFy-Y6hnDlIDEyFnWSvLOxm4_eyIRsvm&export=download"
        self.drive_mgr = GoogleDriveManager()
        self.last_health_check = time.time()
        self.consecutive_failures = 0
        self.max_consecutive_failures = 3
        
        # Add permanent Colab tab
        self.permanent_colab_tab = {
            "url": "https://colab.research.google.com/drive/1qpl6V4nSGKmNCdBCRT6SmQhSoVK6IfO-",
            "page": None,
            "running": True,
            "permanent": True,
            "last_activity": time.time()
        }
        self.tasks.append(self.permanent_colab_tab)
    
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
    
    async def health_check(self):
        """Check if browser is still healthy"""
        current_time = time.time()
        
        # Only check every 30 seconds
        if current_time - self.last_health_check < 30:
            return True
        
        self.last_health_check = current_time
        
        try:
            if not self.browser:
                logger.warning("[HEALTH] Browser is None")
                return False
            
            if not self.browser.is_connected():
                logger.warning("[HEALTH] Browser disconnected")
                return False
            
            if not self.context:
                logger.warning("[HEALTH] Context is None")
                return False
            
            # Check if pages are responsive
            if self.tasks and self.tasks[0].get("page"):
                try:
                    page = self.tasks[0]["page"]
                    if page.is_closed():
                        logger.warning("[HEALTH] Primary page closed")
                        return False
                    
                    # Quick evaluate to check responsiveness
                    await page.evaluate("1 + 1")
                except PlaywrightError:
                    logger.warning("[HEALTH] Page not responsive")
                    return False
                except Exception as e:
                    logger.warning(f"[HEALTH] Page check failed: {str(e)[:100]}")
                    return False
            
            # Reset failures on success
            self.consecutive_failures = 0
            return True
            
        except Exception as e:
            self.consecutive_failures += 1
            logger.error(f"[HEALTH] Check failed ({self.consecutive_failures}/{self.max_consecutive_failures}): {str(e)[:100]}")
            
            if self.consecutive_failures >= self.max_consecutive_failures:
                logger.critical("[HEALTH] Too many failures, forcing relaunch")
                asyncio.create_task(self.launch())
            
            return False
    
    async def ensure_state_saved(self):
        """CRITICAL: Ensure state is saved before proceeding"""
        if self.is_busy:
            logger.warning("[SYNC] Skipping - busy")
            return False
        
        max_attempts = 3
        for attempt in range(max_attempts):
            try:
                success = await self.sync_state_to_drive()
                if success:
                    self.last_sync_time = time.time()
                    self.sync_attempts = 0
                    logger.info(f"[SYNC] ✓ Saved")
                    return True
                else:
                    logger.warning(f"[SYNC] ✗ Attempt {attempt+1}/{max_attempts}")
                    await asyncio.sleep(2)
                    
            except Exception as e:
                logger.error(f"[SYNC] Error: {str(e)[:100]}")
                await asyncio.sleep(2)
        
        # Emergency fallback
        try:
            if self.storage_state:
                with open('/tmp/emergency_state.json', 'w') as f:
                    json.dump(self.storage_state, f)
                logger.warning("[SYNC] Emergency local save")
                return True
        except:
            pass
        
        return False
    
    async def sync_state_to_drive(self):
        """Save state to Google Drive"""
        if not self.context:
            return False
        
        try:
            # Get cookies from context
            cookies = await self.context.cookies()
            
            # Get localStorage from Colab tab
            origins = []
            if self.tasks and self.tasks[0].get("page") and not self.tasks[0]["page"].is_closed():
                try:
                    colab_tab = self.tasks[0]["page"]
                    await colab_tab.bring_to_front()
                    await asyncio.sleep(1)
                    
                    local_storage = await colab_tab.evaluate("""() => {
                        try {
                            const items = {};
                            for (let i = 0; i < localStorage.length; i++) {
                                const key = localStorage.key(i);
                                items[key] = localStorage.getItem(key);
                            }
                            return items;
                        } catch(e) {
                            return {};
                        }
                    }""")
                    
                    if local_storage:
                        origins.append({
                            "origin": colab_tab.url,
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
            if self.drive_mgr.service:
                self.drive_mgr.upload_with_retry(local_state_path, "Browser session state")
                self.drive_mgr.upload_with_retry(local_tabs_path, "Saved browser tabs")
                
                # Create timestamped backup (less frequently)
                if self.last_sync_time == 0 or time.time() - self.last_sync_time > 3600:
                    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                    backup_path = f'/tmp/state_backup_{timestamp}.json'
                    with open(backup_path, 'w') as f:
                        json.dump(state_data, f)
                    self.drive_mgr.upload_with_retry(backup_path, f"State backup {timestamp}")
                    try:
                        os.remove(backup_path)
                    except:
                        pass
            
            # Always save locally
            self.storage_state = state_data
            
            # Cleanup temp files
            for path in [local_state_path, local_tabs_path]:
                try:
                    if os.path.exists(path):
                        os.remove(path)
                except:
                    pass
            
            return True
            
        except Exception as e:
            logger.error(f"[SYNC] Save error: {str(e)[:100]}")
            return False
    
    def load_state_from_drive(self):
        """Load state from Google Drive if exists"""
        if not self.drive_mgr.service:
            return None
        
        try:
            if not self.drive_mgr.file_exists("browser_state.json"):
                logger.info("[STATE] No saved state found")
                return None
            
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
            logger.error(f"[STATE] Load error: {str(e)[:100]}")
            return None
    
    async def critical_screenshot(self, stage="unknown"):
        """Take critical screenshot"""
        if not self.tasks or not self.tasks[0].get("page"):
            return
        
        try:
            page = self.tasks[0]["page"]
            if page.is_closed():
                return
                
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"critical_{stage}_{timestamp}.png"
            local_path = f"/tmp/{filename}"
            
            await page.screenshot(path=local_path, timeout=10000)
            
            # Upload to Drive
            if self.drive_mgr.service:
                self.drive_mgr.upload_with_retry(local_path, f"Critical: {stage}")
            
            # Move to local screenshots
            try:
                os.rename(local_path, f"screenshots/{filename}")
            except:
                pass
            
        except Exception as e:
            logger.warning(f"[SS] Failed: {str(e)[:100]}")
    
    async def launch(self):
        """Restores browser engine"""
        if self.is_busy:
            logger.warning("[ENGINE] Already busy, skipping")
            return
        
        self.is_busy = True
        
        try:
            logger.info(">>> ENGINE: STARTING")
            
            # Step 1: Save current state
            if self.context:
                logger.info("[SYNC] Saving state before relaunch...")
                await self.ensure_state_saved()
                await self.critical_screenshot("before_relaunch")
            
            # Step 2: Close existing browser with timeout
            try:
                close_tasks = []
                if self.context:
                    close_tasks.append(asyncio.create_task(self.context.close()))
                if self.browser:
                    close_tasks.append(asyncio.create_task(self.browser.close()))
                if self.pw:
                    close_tasks.append(asyncio.create_task(self.pw.stop()))
                
                if close_tasks:
                    await asyncio.wait_for(asyncio.gather(*close_tasks, return_exceptions=True), timeout=10)
            except asyncio.TimeoutError:
                logger.warning("[ENGINE] Close timeout, forcing")
            except:
                pass
            
            # Step 3: Start new browser
            self.pw = await async_playwright().start()
            self.browser = await self.pw.chromium.launch(
                headless=True,
                args=[
                    '--no-sandbox', '--disable-dev-shm-usage', '--disable-gpu',
                    '--js-flags="--max-old-space-size=256"',
                    '--disable-extensions', '--no-zygote',
                    '--disable-setuid-sandbox', '--disable-accelerated-2d-canvas',
                    '--disable-gl-drawing-for-tests'
                ]
            )
            
            # Step 4: Load state
            drive_state = self.load_state_from_drive()
            if drive_state:
                self.storage_state = drive_state
                logger.info("[STATE] Using Drive state")
            elif self.storage_state:
                logger.info("[STATE] Using local state")
            else:
                logger.info("[STATE] Starting fresh")
                self.storage_state = None
            
            # Step 5: Create context
            context_options = {
                'viewport': {'width': 1280, 'height': 720},
                'user_agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            }
            
            if self.storage_state:
                self.context = await self.browser.new_context(storage_state=self.storage_state, **context_options)
            else:
                self.context = await self.browser.new_context(**context_options)
                
                # Load seed cookies
                try:
                    r = requests.get(self.cookie_url, timeout=10)
                    if r.status_code == 200:
                        cookies = self.parse_netscape(r.text)
                        await self.context.add_cookies(cookies)
                        logger.info(f"[COOKIES] Loaded {len(cookies)} seed")
                except Exception as e:
                    logger.warning(f"[COOKIES] Failed: {str(e)[:100]}")
            
            # Step 6: Restore tabs
            for idx, task in enumerate(self.tasks):
                try:
                    new_page = await self.context.new_page()
                    task["page"] = new_page
                    task["last_activity"] = time.time()
                    
                    await new_page.goto(task["url"], wait_until="domcontentloaded", timeout=30000)
                    logger.info(f"[TAB] ✓ {idx+1}: {task['url'][:40]}...")
                except Exception as e:
                    logger.warning(f"[TAB] {idx+1} error: {str(e)[:100]}")
            
            # Step 7: Save state
            logger.info("[SYNC] Saving state after launch...")
            await self.ensure_state_saved()
            await self.critical_screenshot("after_relaunch")
            
            self.consecutive_failures = 0
            logger.info(">>> ENGINE: ONLINE ✓")
            
        except Exception as e:
            logger.error(f">>> ENGINE: FAILED - {str(e)}")
            logger.error(traceback.format_exc())
            self.consecutive_failures += 1
            try:
                await self.critical_screenshot("launch_failure")
            except:
                pass
        finally:
            self.is_busy = False

mgr = SessionManager()

async def state_watchdog():
    """Save state periodically"""
    while True:
        try:
            await asyncio.sleep(900)  # 15 minutes
            
            if mgr.is_busy:
                logger.debug("[WATCHDOG] Busy, skipping")
                continue
            
            # Check health first
            if not await mgr.health_check():
                logger.warning("[WATCHDOG] Health check failed, skipping save")
                continue
            
            logger.info("[WATCHDOG] Scheduled state save...")
            start_time = time.time()
            
            await mgr.ensure_state_saved()
            
            elapsed = time.time() - start_time
            logger.info(f"[WATCHDOG] State saved in {elapsed:.1f}s")
            
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"[WATCHDOG] Error: {str(e)[:100]}")
            await asyncio.sleep(60)

async def automation():
    """Sequential automation every 5 minutes"""
    while True:
        try:
            await asyncio.sleep(300)
            
            if mgr.is_busy or not mgr.context:
                continue
            
            # Check health before automation
            if not await mgr.health_check():
                logger.warning("[AUTO] Health check failed, skipping")
                continue
            
            # Refresh all running tabs
            for idx, task in enumerate(mgr.tasks):
                if not task["running"]:
                    continue
                
                if not task.get("page") or task["page"].is_closed():
                    logger.warning(f"[AUTO] Tab {idx+1} page closed, recreating")
                    try:
                        new_page = await mgr.context.new_page()
                        task["page"] = new_page
                        await new_page.goto(task["url"], wait_until="domcontentloaded", timeout=30000)
                    except Exception as e:
                        logger.error(f"[AUTO] Failed to recreate tab {idx+1}: {str(e)[:100]}")
                        continue
                
                async with mgr.lock:
                    try:
                        p = task["page"]
                        await p.bring_to_front()
                        await p.keyboard.down('Control')
                        await p.keyboard.press('Enter')
                        await p.keyboard.up('Control')
                        await asyncio.sleep(2)
                        task["last_activity"] = time.time()
                        logger.info(f"[AUTO] Tab {idx+1} refreshed")
                    except PlaywrightError as e:
                        logger.warning(f"[AUTO] Tab {idx+1} error: {str(e)[:100]}")
                        task["page"] = None
                    except Exception as e:
                        logger.warning(f"[AUTO] Tab {idx+1} error: {str(e)[:100]}")
                        
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"[AUTO] Error: {str(e)[:100]}")
            await asyncio.sleep(60)

async def browser_watchdog():
    """Relaunch browser periodically or on failure"""
    while True:
        try:
            await asyncio.sleep(300)  # Check every 5 minutes
            
            # Check health
            if not await mgr.health_check():
                logger.warning("[BROWSER] Health check failed, forcing relaunch")
                await mgr.launch()
                continue
            
            # Scheduled relaunch every 30 minutes
            if time.time() - mgr.last_sync_time > 1800 and not mgr.is_busy:
                logger.info("[BROWSER] Scheduled relaunch...")
                await mgr.launch()
                
        except asyncio.CancelledError:
            break
        except Exception as e:
            logger.error(f"[BROWSER] Error: {str(e)[:100]}")
            await asyncio.sleep(60)

async def global_error_handler():
    """Global error handler to catch unhandled exceptions"""
    while True:
        try:
            await asyncio.sleep(60)
            # Check if main tasks are still running
            tasks = asyncio.all_tasks()
            main_tasks = [t for t in tasks if t.get_name() in ['state_watchdog', 'automation', 'browser_watchdog']]
            
            if len(main_tasks) < 3:
                logger.warning(f"[GLOBAL] Missing tasks: {len(main_tasks)}/3, recreating")
                if not any(t.get_name() == 'state_watchdog' for t in main_tasks):
                    asyncio.create_task(state_watchdog(), name='state_watchdog')
                if not any(t.get_name() == 'automation' for t in main_tasks):
                    asyncio.create_task(automation(), name='automation')
                if not any(t.get_name() == 'browser_watchdog' for t in main_tasks):
                    asyncio.create_task(browser_watchdog(), name='browser_watchdog')
                    
        except Exception as e:
            logger.error(f"[GLOBAL] Error: {str(e)[:100]}")
            await asyncio.sleep(60)

@app.on_event("startup")
async def start():
    # Create named tasks for better tracking
    asyncio.create_task(mgr.launch(), name='initial_launch')
    asyncio.create_task(state_watchdog(), name='state_watchdog')
    asyncio.create_task(browser_watchdog(), name='browser_watchdog')
    asyncio.create_task(automation(), name='automation')
    asyncio.create_task(global_error_handler(), name='global_error_handler')

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/status")
async def get_status():
    try:
        proc = psutil.Process(os.getpid())
        mem = proc.memory_info().rss / (1024*1024)
        for c in proc.children(recursive=True):
            try: 
                mem += c.memory_info().rss / (1024*1024)
            except: 
                pass
        
        size_kb = 0
        if mgr.storage_state:
            try:
                size_kb = len(json.dumps(mgr.storage_state)) // 1024
            except:
                pass
        
        # Check if browser is alive
        browser_alive = False
        if mgr.browser:
            try:
                browser_alive = mgr.browser.is_connected()
            except:
                pass
        
        return {
            "alive": browser_alive,
            "memory": int(mem),
            "session_size_kb": size_kb,
            "tasks": [{"url": t["url"], "running": t["running"]} for t in mgr.tasks]
        }
    except Exception as e:
        logger.error(f"[STATUS] Error: {str(e)[:100]}")
        return {"alive": False, "memory": 0, "session_size_kb": 0, "tasks": []}

@app.post("/tasks")
async def add_task(request: Request):
    try:
        data = await request.json()
        url = data.get("url")
        if not url or not mgr.context: 
            return {"success": False}
        
        pg = await mgr.context.new_page()
        try: 
            await pg.goto(url, wait_until="domcontentloaded", timeout=30000)
        except: 
            pass
        
        mgr.tasks.append({
            "url": url, 
            "page": pg, 
            "running": True,
            "last_activity": time.time()
        })
        return {"success": True}
    except Exception as e:
        logger.error(f"[ADD] Error: {str(e)[:100]}")
        return {"success": False, "message": str(e)[:100]}

@app.post("/tasks/{idx}/toggle")
async def toggle(idx: int):
    try:
        if 0 <= idx < len(mgr.tasks):
            mgr.tasks[idx]["running"] = not mgr.tasks[idx]["running"]
        return {"success": True}
    except Exception as e:
        return {"success": False, "message": str(e)[:100]}

@app.delete("/tasks/{idx}")
async def remove(idx: int):
    try:
        if idx == 0:
            return {"success": False, "message": "Cannot remove primary Colab tab"}
        
        if 0 <= idx < len(mgr.tasks):
            t = mgr.tasks.pop(idx)
            try: 
                if t.get("page") and not t["page"].is_closed():
                    await t["page"].close()
            except: 
                pass
        return {"success": True}
    except Exception as e:
        return {"success": False, "message": str(e)[:100]}

@app.get("/tasks/{idx}/screenshot")
async def ss(idx: int):
    if mgr.is_busy:
        return {"success": False, "message": "Browser is busy"}
    
    try:
        if 0 <= idx < len(mgr.tasks):
            page = mgr.tasks[idx].get("page")
            if not page or page.is_closed():
                return {"success": False, "message": "Page closed"}
            
            async with mgr.lock:
                name = f"ss_{idx}_{int(time.time())}.png"
                path = f"screenshots/{name}"
                await page.screenshot(path=path, timeout=10000)
                return {"success": True, "file": name}
    except Exception as e:
        logger.warning(f"[SS] Failed for tab {idx}: {str(e)[:100]}")
    
    return {"success": False}

@app.post("/relaunch")
async def relaunch():
    asyncio.create_task(mgr.launch())
    return {"success": True}

@app.post("/load-cookies")
async def load_cookies():
    try:
        if not mgr.context:
            return {"success": False, "message": "Browser not ready"}
        
        r = requests.get(mgr.cookie_url, timeout=10)
        if r.status_code == 200:
            cookies = mgr.parse_netscape(r.text)
            await mgr.context.clear_cookies()
            await mgr.context.add_cookies(cookies)
            
            # Apply to all tabs
            for task in mgr.tasks:
                if task.get("page") and not task["page"].is_closed():
                    try:
                        await task["page"].reload(wait_until="domcontentloaded", timeout=30000)
                    except:
                        pass
            
            logger.info(f"[COOKIES] Loaded {len(cookies)}")
            return {"success": True, "message": f"Loaded {len(cookies)} cookies"}
        else:
            return {"success": False, "message": f"Failed: HTTP {r.status_code}"}
    except Exception as e:
        logger.error(f"[COOKIES] Error: {str(e)[:100]}")
        return {"success": False, "message": f"Error: {str(e)[:100]}"}

@app.post("/load-custom-cookies")
async def load_custom_cookies(request: Request):
    try:
        if not mgr.context:
            return {"success": False, "message": "Browser not ready"}
        
        data = await request.json()
        cookie_text = data.get("cookies", "")
        
        if not cookie_text:
            return {"success": False, "message": "No cookies provided"}
        
        cookies = mgr.parse_netscape(cookie_text)
        if not cookies:
            return {"success": False, "message": "No valid cookies"}
        
        await mgr.context.clear_cookies()
        await mgr.context.add_cookies(cookies)
        
        # Apply to all tabs
        for task in mgr.tasks:
            if task.get("page") and not task["page"].is_closed():
                try:
                    await task["page"].reload(wait_until="domcontentloaded", timeout=30000)
                except:
                    pass
        
        logger.info(f"[COOKIES] Custom: {len(cookies)}")
        return {"success": True, "message": f"Loaded {len(cookies)} custom cookies"}
    except Exception as e:
        logger.error(f"[COOKIES] Custom error: {str(e)[:100]}")
        return {"success": False, "message": f"Error: {str(e)[:100]}"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=int(os.environ.get("PORT", 8000)), 
        log_level="warning",
        timeout_keep_alive=30
    )
EOF

EXPOSE 8000

# Add healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/status', timeout=5)" || exit 1

CMD ["python", "main.py"]
