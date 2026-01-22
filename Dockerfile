FROM python:3.11-slim

# Install ALL dependencies that Playwright needs
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

# Install Playwright and web framework
RUN pip install playwright==1.40.0 fastapi==0.104.1 uvicorn==0.24.0 python-multipart jinja2 requests

# Install Chromium browser
RUN playwright install chromium

# Create HTML template for multiple automations
RUN mkdir -p templates && cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🤖 Multi-Colab Automation Dashboard</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .dashboard {
            display: grid;
            grid-template-columns: 2fr 1fr;
            gap: 20px;
            margin-top: 20px;
        }
        
        @media (max-width: 1024px) {
            .dashboard {
                grid-template-columns: 1fr;
            }
        }
        
        .card {
            background: white;
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            margin-bottom: 20px;
        }
        
        h1 {
            color: white;
            text-align: center;
            margin-bottom: 10px;
            font-size: 2.5rem;
        }
        
        .subtitle {
            color: rgba(255,255,255,0.9);
            text-align: center;
            margin-bottom: 30px;
            font-size: 1.1rem;
        }
        
        h2 {
            color: #333;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        h2 i {
            font-size: 1.5rem;
        }
        
        .automation-controls {
            margin-bottom: 25px;
        }
        
        .url-input-group {
            margin-bottom: 15px;
        }
        
        .url-input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 14px;
            transition: border 0.3s;
        }
        
        .url-input:focus {
            border-color: #667eea;
            outline: none;
        }
        
        .url-input::placeholder {
            color: #999;
        }
        
        .button-group {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 10px;
            margin-bottom: 15px;
        }
        
        .btn {
            padding: 12px 20px;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
        }
        
        .btn-primary {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }
        
        .btn-secondary {
            background: #f0f0f0;
            color: #333;
        }
        
        .btn-secondary:hover {
            background: #e0e0e0;
            transform: translateY(-2px);
        }
        
        .btn-danger {
            background: #ff4757;
            color: white;
        }
        
        .btn-danger:hover {
            background: #ff3742;
            transform: translateY(-2px);
        }
        
        .btn-success {
            background: #2ed573;
            color: white;
        }
        
        .btn-success:hover {
            background: #25c464;
            transform: translateY(-2px);
        }
        
        .btn-warning {
            background: #ffa502;
            color: white;
        }
        
        .btn-warning:hover {
            background: #e59400;
            transform: translateY(-2px);
        }
        
        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none !important;
        }
        
        .btn-sm {
            padding: 6px 12px;
            font-size: 12px;
        }
        
        .automation-list {
            margin-top: 20px;
            max-height: 400px;
            overflow-y: auto;
        }
        
        .automation-item {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 15px;
            margin-bottom: 10px;
            border-left: 4px solid #2ed573;
            transition: all 0.3s;
        }
        
        .automation-item.running {
            border-left-color: #2ed573;
        }
        
        .automation-item.stopped {
            border-left-color: #ff4757;
        }
        
        .automation-item.paused {
            border-left-color: #ffa502;
        }
        
        .automation-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
        }
        
        .automation-title {
            font-weight: 600;
            font-size: 14px;
            color: #333;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 70%;
        }
        
        .automation-status {
            font-size: 11px;
            font-weight: 600;
            padding: 3px 8px;
            border-radius: 12px;
            text-transform: uppercase;
        }
        
        .status-running {
            background: #2ed573;
            color: white;
        }
        
        .status-stopped {
            background: #ff4757;
            color: white;
        }
        
        .status-paused {
            background: #ffa502;
            color: white;
        }
        
        .automation-url {
            font-size: 12px;
            color: #666;
            margin-bottom: 8px;
            word-break: break-all;
        }
        
        .automation-controls-small {
            display: flex;
            gap: 8px;
            margin-top: 10px;
        }
        
        .automation-info {
            font-size: 11px;
            color: #888;
            display: flex;
            justify-content: space-between;
            margin-top: 5px;
        }
        
        .screenshot-container {
            text-align: center;
            margin-top: 20px;
        }
        
        .screenshot-img {
            max-width: 100%;
            border-radius: 8px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            border: 2px solid #e0e0e0;
        }
        
        .no-screenshot {
            color: #666;
            font-style: italic;
            padding: 40px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        
        .no-automations {
            color: #999;
            font-style: italic;
            text-align: center;
            padding: 40px;
            background: #f8f9fa;
            border-radius: 8px;
        }
        
        .log-box {
            background: #1e1e1e;
            color: #00ff00;
            padding: 20px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            font-size: 12px;
            height: 400px;
            overflow-y: auto;
            margin-top: 10px;
            white-space: pre-wrap;
        }
        
        .log-entry {
            margin-bottom: 5px;
            padding: 5px 0;
            border-bottom: 1px solid #333;
        }
        
        .log-time {
            color: #888;
        }
        
        .log-info {
            color: #00ff00;
        }
        
        .log-success {
            color: #2ed573;
        }
        
        .log-warning {
            color: #ffa502;
        }
        
        .log-error {
            color: #ff4757;
        }
        
        .log-automation {
            color: #3498db;
        }
        
        .status-card {
            margin-top: 20px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 5px solid #667eea;
        }
        
        .status-title {
            font-weight: 600;
            margin-bottom: 5px;
            color: #333;
            font-size: 13px;
        }
        
        .status-value {
            color: #666;
            font-family: monospace;
            font-size: 12px;
            word-break: break-all;
        }
        
        .loading {
            display: none;
            text-align: center;
            padding: 20px;
        }
        
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 30px;
            height: 30px;
            animation: spin 1s linear infinite;
            margin: 0 auto 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .notification {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 12px 20px;
            border-radius: 8px;
            color: white;
            font-weight: 600;
            font-size: 14px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
            z-index: 1000;
            display: none;
            animation: slideIn 0.3s ease-out;
        }
        
        @keyframes slideIn {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }
        
        .notification.success {
            background: #2ed573;
        }
        
        .notification.error {
            background: #ff4757;
        }
        
        .notification.info {
            background: #2f3542;
        }
        
        .notification.warning {
            background: #ffa502;
        }
        
        .tab-controls {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        
        .tab-btn {
            padding: 8px 16px;
            background: rgba(255,255,255,0.1);
            color: white;
            border: 2px solid rgba(255,255,255,0.3);
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            transition: all 0.3s;
        }
        
        .tab-btn:hover {
            background: rgba(255,255,255,0.2);
        }
        
        .tab-btn.active {
            background: white;
            color: #667eea;
            border-color: white;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 10px;
            margin-top: 15px;
        }
        
        .stat-box {
            background: #f8f9fa;
            padding: 12px;
            border-radius: 8px;
            text-align: center;
        }
        
        .stat-value {
            font-size: 20px;
            font-weight: 700;
            color: #667eea;
        }
        
        .stat-label {
            font-size: 11px;
            color: #666;
            margin-top: 5px;
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <h1><i class="fas fa-robot"></i> Multi-Colab Automation Dashboard</h1>
        <p class="subtitle">Run multiple Colab automations simultaneously</p>
        
        <div class="tab-controls">
            <button class="tab-btn active" data-tab="automations">🤖 Automations</button>
            <button class="tab-btn" data-tab="browser">🌐 Browser Control</button>
            <button class="tab-btn" data-tab="screenshots">📸 Screenshots</button>
            <button class="tab-btn" data-tab="logs">📋 Logs</button>
        </div>
        
        <div class="dashboard">
            <!-- Main Column -->
            <div id="automations-tab" class="tab-content active">
                <div class="card">
                    <h2><i class="fas fa-plus-circle"></i> Create New Automation</h2>
                    
                    <div class="url-input-group">
                        <input type="url" 
                               id="newAutomationUrl" 
                               class="url-input" 
                               placeholder="https://colab.research.google.com/drive/..."
                               value="https://colab.research.google.com/">
                    </div>
                    
                    <div class="button-group">
                        <button id="createAutomationBtn" class="btn btn-primary">
                            <i class="fas fa-plus"></i> Create Automation
                        </button>
                        <button id="addFromCurrentBtn" class="btn btn-secondary">
                            <i class="fas fa-clone"></i> Use Current Page
                        </button>
                    </div>
                    
                    <div class="automation-controls">
                        <button id="startAllBtn" class="btn btn-success">
                            <i class="fas fa-play-circle"></i> Start All
                        </button>
                        <button id="stopAllBtn" class="btn btn-danger">
                            <i class="fas fa-stop-circle"></i> Stop All
                        </button>
                        <button id="pauseAllBtn" class="btn btn-warning">
                            <i class="fas fa-pause-circle"></i> Pause All
                        </button>
                        <button id="refreshAllBtn" class="btn btn-secondary">
                            <i class="fas fa-redo"></i> Refresh All
                        </button>
                    </div>
                </div>
                
                <div class="card">
                    <h2><i class="fas fa-list"></i> Active Automations</h2>
                    
                    <div class="stats-grid">
                        <div class="stat-box">
                            <div class="stat-value" id="totalAutomations">0</div>
                            <div class="stat-label">Total</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-value" id="runningAutomations">0</div>
                            <div class="stat-label">Running</div>
                        </div>
                        <div class="stat-box">
                            <div class="stat-value" id="pausedAutomations">0</div>
                            <div class="stat-label">Paused</div>
                        </div>
                    </div>
                    
                    <div class="automation-list" id="automationList">
                        <div class="no-automations">
                            <i class="fas fa-robot fa-3x" style="color: #ddd; margin-bottom: 15px;"></i><br>
                            No automations yet. Create one above!
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Browser Control Tab -->
            <div id="browser-tab" class="tab-content">
                <div class="card">
                    <h2><i class="fas fa-compass"></i> Browser Navigation</h2>
                    
                    <div class="url-input-group">
                        <input type="url" 
                               id="browserUrl" 
                               class="url-input" 
                               placeholder="https://example.com"
                               value="https://www.google.com">
                    </div>
                    
                    <div class="button-group">
                        <button id="browserGoBtn" class="btn btn-primary">
                            <i class="fas fa-external-link-alt"></i> Go
                        </button>
                        <button id="browserScreenshotBtn" class="btn btn-secondary">
                            <i class="fas fa-camera"></i> Screenshot
                        </button>
                    </div>
                    
                    <div class="automation-controls">
                        <button id="browserBackBtn" class="btn btn-secondary">
                            <i class="fas fa-arrow-left"></i> Back
                        </button>
                        <button id="browserForwardBtn" class="btn btn-secondary">
                            <i class="fas fa-arrow-right"></i> Forward
                        </button>
                        <button id="browserReloadBtn" class="btn btn-secondary">
                            <i class="fas fa-redo"></i> Reload
                        </button>
                        <button id="browserHomeBtn" class="btn btn-secondary">
                            <i class="fas fa-home"></i> Home
                        </button>
                    </div>
                </div>
                
                <div class="card">
                    <h2><i class="fas fa-info-circle"></i> Browser Status</h2>
                    
                    <div class="status-card">
                        <div class="status-title">Current URL</div>
                        <div id="browserCurrentUrl" class="status-value">Loading...</div>
                    </div>
                    
                    <div class="status-card">
                        <div class="status-title">Cookies Status</div>
                        <div id="browserCookiesStatus" class="status-value">
                            <span id="cookiesCount">0</span> cookies loaded
                            <span id="cookiesIndicator" class="cookie-status cookie-bad">❌</span>
                        </div>
                    </div>
                    
                    <div class="status-card">
                        <div class="status-title">Session Status</div>
                        <div id="browserSessionStatus" class="status-value">Active</div>
                    </div>
                    
                    <div class="automation-controls">
                        <button id="refreshCookiesBtn" class="btn btn-warning">
                            <i class="fas fa-redo"></i> Refresh Cookies
                        </button>
                        <button id="clearCookiesBtn" class="btn btn-danger">
                            <i class="fas fa-trash"></i> Clear Cookies
                        </button>
                    </div>
                </div>
            </div>
            
            <!-- Screenshots Tab -->
            <div id="screenshots-tab" class="tab-content">
                <div class="card">
                    <h2><i class="fas fa-image"></i> Live Screenshot</h2>
                    
                    <div class="screenshot-container">
                        <div id="screenshotPlaceholder" class="no-screenshot">
                            <i class="fas fa-image fa-3x" style="color: #ddd; margin-bottom: 15px;"></i><br>
                            No screenshot yet
                        </div>
                        <img id="screenshotImage" class="screenshot-img" style="display: none;" alt="Live Screenshot">
                    </div>
                    
                    <div class="button-group" style="margin-top: 20px;">
                        <button id="takeScreenshotBtn" class="btn btn-primary">
                            <i class="fas fa-camera"></i> Take Screenshot
                        </button>
                        <button id="downloadScreenshotBtn" class="btn btn-secondary">
                            <i class="fas fa-download"></i> Download
                        </button>
                    </div>
                </div>
                
                <div class="card">
                    <h2><i class="fas fa-history"></i> Recent Screenshots</h2>
                    <div id="recentScreenshots" class="no-automations">
                        No recent screenshots
                    </div>
                </div>
            </div>
            
            <!-- Logs Tab -->
            <div id="logs-tab" class="tab-content">
                <div class="card">
                    <h2><i class="fas fa-terminal"></i> System Logs</h2>
                    
                    <div class="log-box" id="logBox">
                        <div class="log-entry">
                            <span class="log-time">[System]</span>
                            <span class="log-info"> Dashboard initialized</span>
                        </div>
                    </div>
                    
                    <div class="automation-controls" style="margin-top: 15px;">
                        <button id="clearLogsBtn" class="btn btn-secondary">
                            <i class="fas fa-trash"></i> Clear Logs
                        </button>
                        <button id="exportLogsBtn" class="btn btn-secondary">
                            <i class="fas fa-download"></i> Export Logs
                        </button>
                        <button id="autoScrollBtn" class="btn btn-success">
                            <i class="fas fa-arrow-down"></i> Auto-scroll: ON
                        </button>
                    </div>
                </div>
            </div>
            
            <!-- Right Column -->
            <div>
                <div class="card">
                    <h2><i class="fas fa-tachometer-alt"></i> System Status</h2>
                    
                    <div class="status-card">
                        <div class="status-title">Total Automations</div>
                        <div id="statusTotal" class="status-value">0</div>
                    </div>
                    
                    <div class="status-card">
                        <div class="status-title">Active Tasks</div>
                        <div id="statusActive" class="status-value">0</div>
                    </div>
                    
                    <div class="status-card">
                        <div class="status-title">Uptime</div>
                        <div id="statusUptime" class="status-value">00:00:00</div>
                    </div>
                    
                    <div class="status-card">
                        <div class="status-title">Last Update</div>
                        <div id="statusLastUpdate" class="status-value" style="color: #999;">-</div>
                    </div>
                </div>
                
                <div class="card">
                    <h2><i class="fas fa-cogs"></i> Quick Actions</h2>
                    
                    <div class="automation-controls">
                        <button id="quickStartBtn" class="btn btn-success">
                            <i class="fas fa-bolt"></i> Quick Start
                        </button>
                        <button id="quickStopBtn" class="btn btn-danger">
                            <i class="fas fa-stop"></i> Quick Stop
                        </button>
                        <button id="refreshStatusBtn" class="btn btn-secondary">
                            <i class="fas fa-sync"></i> Refresh Status
                        </button>
                    </div>
                    
                    <div style="margin-top: 15px; font-size: 12px; color: #666;">
                        <p><i class="fas fa-info-circle"></i> <strong>Multiple Automation Support:</strong></p>
                        <ul style="margin-left: 15px; margin-top: 5px;">
                            <li>Run multiple Colab tabs simultaneously</li>
                            <li>Each automation runs independently</li>
                            <li>Pause/resume individual automations</li>
                            <li>Monitor all from single dashboard</li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Loading Overlay -->
    <div id="loadingOverlay" class="loading">
        <div class="spinner"></div>
        <div id="loadingText">Processing...</div>
    </div>
    
    <!-- Notification -->
    <div id="notification" class="notification"></div>
    
    <!-- Automation Details Modal -->
    <div id="automationModal" class="modal" style="display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 1001; align-items: center; justify-content: center;">
        <div class="card" style="max-width: 500px; width: 90%; max-height: 80vh; overflow-y: auto;">
            <h2><i class="fas fa-robot"></i> Automation Details</h2>
            <div id="modalContent"></div>
            <button id="closeModalBtn" class="btn btn-secondary" style="margin-top: 20px; width: 100%;">
                <i class="fas fa-times"></i> Close
            </button>
        </div>
    </div>
    
    <script>
        // Complete JavaScript will be provided in next message due to length
        // This is the structure for multi-automation support
    </script>
</body>
</html>
EOF

# Create the Python server with multi-automation support
RUN cat > main.py << 'EOF'
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse, StreamingResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from playwright.async_api import async_playwright
import uuid
import os
import asyncio
import time
from datetime import datetime, timedelta
import logging
import json
from typing import Dict, List, Optional
from dataclasses import dataclass, asdict
from enum import Enum

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Enums
class AutomationStatus(Enum):
    RUNNING = "running"
    STOPPED = "stopped"
    PAUSED = "paused"
    ERROR = "error"

@dataclass
class Automation:
    id: str
    url: str
    name: str
    status: AutomationStatus
    created_at: datetime
    last_run: Optional[datetime]
    total_runs: int
    interval_minutes: int
    next_run: Optional[datetime]
    page: Optional = None
    context: Optional = None
    
    def to_dict(self):
        data = asdict(self)
        data['status'] = self.status.value
        data['created_at'] = self.created_at.isoformat()
        data['last_run'] = self.last_run.isoformat() if self.last_run else None
        data['next_run'] = self.next_run.isoformat() if self.next_run else None
        return data

# Global state
browser = None
playwright_instance = None
main_page = None
main_context = None
automations: Dict[str, Automation] = {}
cookies = []
startup_time = datetime.now()

# Cookies download URL
COOKIES_DOWNLOAD_URL = "https://drive.usercontent.google.com/download?id=1NFy-Y6hnDlIDEyFnWSvLOxm4_eyIRsvm&export=download"

def parse_netscape_cookies(content: str):
    """Parse Netscape format cookies from text content."""
    cookies_list = []
    lines = content.strip().split('\n')
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        
        parts = line.split('\t')
        if len(parts) >= 7:
            try:
                cookie = {
                    "name": parts[5],
                    "value": parts[6],
                    "domain": parts[0],
                    "path": parts[2],
                    "secure": parts[3].lower() == "true",
                }
                cookies_list.append(cookie)
            except Exception as e:
                logger.warning(f"Failed to parse cookie: {e}")
    
    return cookies_list

async def download_cookies():
    """Download and parse cookies."""
    global cookies
    try:
        import requests
        logger.info("📥 Downloading cookies...")
        response = requests.get(COOKIES_DOWNLOAD_URL, timeout=10)
        
        if response.status_code == 200:
            cookies = parse_netscape_cookies(response.text)
            logger.info(f"✅ Downloaded {len(cookies)} cookies")
            return True
        else:
            logger.error(f"❌ Failed to download cookies: {response.status_code}")
            return False
    except Exception as e:
        logger.error(f"❌ Cookie download error: {e}")
        return False

async def init_browser():
    """Initialize main browser with cookies."""
    global browser, main_page, main_context, playwright_instance, cookies
    
    try:
        logger.info("🚀 Initializing main browser...")
        
        # Download cookies first
        await download_cookies()
        
        # Start Playwright
        playwright_instance = await async_playwright().start()
        browser = await playwright_instance.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage', '--disable-blink-features=AutomationControlled']
        )
        
        # Create main context with user agent
        main_context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            ignore_https_errors=True
        )
        
        # Add cookies if available
        if cookies:
            await main_context.add_cookies(cookies)
            logger.info(f"✅ Added {len(cookies)} cookies to browser")
        
        # Create main page
        main_page = await main_context.new_page()
        
        # Navigate to Google
        logger.info("🌐 Navigating to google.com...")
        await main_page.goto("https://www.google.com", wait_until="domcontentloaded", timeout=30000)
        
        # Take initial screenshot
        await take_screenshot("initial")
        
        logger.info("✅ Main browser initialized successfully")
        return True
        
    except Exception as e:
        logger.error(f"❌ Browser initialization error: {e}")
        return False

async def take_screenshot(label: str = "", page=None):
    """Take screenshot of a page."""
    target_page = page or main_page
    
    if not target_page:
        return None
    
    try:
        filename = f"screenshot_{label}_{uuid.uuid4().hex[:8]}_{int(time.time())}.png"
        filepath = os.path.join("screenshots", filename)
        
        # Add a small delay to ensure page is stable
        await asyncio.sleep(1)
        
        await target_page.screenshot(path=filepath, full_page=True)
        logger.info(f"📸 Screenshot saved: {filename}")
        
        # Clean old screenshots (keep last 50)
        try:
            screenshots = sorted(os.listdir("screenshots"), key=lambda x: os.path.getctime(os.path.join("screenshots", x)))
            for old_file in screenshots[:-50]:
                try:
                    os.remove(os.path.join("screenshots", old_file))
                except:
                    pass
        except:
            pass
        
        return filename
        
    except Exception as e:
        logger.error(f"❌ Screenshot error: {e}")
        return None

async def create_automation_context():
    """Create a new browser context for an automation."""
    try:
        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            ignore_https_errors=True
        )
        
        # Add cookies to new context
        if cookies:
            await context.add_cookies(cookies)
        
        return context
    except Exception as e:
        logger.error(f"❌ Failed to create automation context: {e}")
        return None

async def automation_worker(automation_id: str):
    """Background worker for an automation."""
    global automations
    
    automation = automations.get(automation_id)
    if not automation:
        return
    
    try:
        # Create new context for this automation
        context = await create_automation_context()
        if not context:
            automation.status = AutomationStatus.ERROR
            return
        
        page = await context.new_page()
        
        # Store page and context in automation
        automation.context = context
        automation.page = page
        
        # Navigate to URL
        logger.info(f"🌐 Automation {automation_id}: Navigating to {automation.url}")
        await page.goto(automation.url, wait_until="domcontentloaded", timeout=60000)
        
        iteration = 0
        while automation.status == AutomationStatus.RUNNING:
            try:
                iteration += 1
                logger.info(f"⏱️ Automation {automation_id}: Iteration {iteration} - Pressing Ctrl+Enter...")
                
                # Press Ctrl+Enter
                await page.focus('body')
                await page.keyboard.down('Control')
                await page.keyboard.press('Enter')
                await page.keyboard.up('Control')
                
                automation.last_run = datetime.now()
                automation.total_runs += 1
                automation.next_run = automation.last_run + timedelta(minutes=automation.interval_minutes)
                
                logger.info(f"✅ Automation {automation_id}: Ctrl+Enter pressed (iteration {iteration})")
                
                # Wait for interval
                for _ in range(automation.interval_minutes * 60):
                    if automation.status != AutomationStatus.RUNNING:
                        break
                    await asyncio.sleep(1)
                    
            except Exception as e:
                logger.error(f"❌ Automation {automation_id} error: {e}")
                await asyncio.sleep(10)
        
        # Cleanup
        if page:
            await page.close()
        if context:
            await context.close()
        
        logger.info(f"🛑 Automation {automation_id} stopped")
        
    except Exception as e:
        logger.error(f"❌ Automation worker error for {automation_id}: {e}")
        automation.status = AutomationStatus.ERROR

async def cleanup_resources():
    """Cleanup all resources."""
    global browser, playwright_instance, automations
    
    # Stop all automations
    for automation_id in list(automations.keys()):
        automations[automation_id].status = AutomationStatus.STOPPED
    
    # Close browser
    if browser:
        try:
            await browser.close()
            logger.info("✅ Browser closed")
        except:
            pass
    
    if playwright_instance:
        try:
            await playwright_instance.stop()
            logger.info("✅ Playwright stopped")
        except:
            pass

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for FastAPI."""
    # Startup
    logger.info("=" * 60)
    logger.info("🤖 Multi-Colab Automation Dashboard Starting")
    logger.info("=" * 60)
    
    # Initialize browser
    success = await init_browser()
    if not success:
        logger.error("❌ Failed to initialize browser - some features may not work")
    else:
        logger.info("✅ Browser ready and waiting for connections")
    
    yield  # App runs here
    
    # Shutdown
    logger.info("🛑 Shutting down...")
    await cleanup_resources()
    logger.info("👋 Server shutdown complete")

# Create FastAPI app with lifespan
app = FastAPI(title="Multi-Colab Automation Dashboard", lifespan=lifespan)

# Setup templates
templates = Jinja2Templates(directory="templates")

# Create directories
os.makedirs("screenshots", exist_ok=True)
os.makedirs("static", exist_ok=True)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Serve the dashboard."""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/status")
async def get_status():
    """Get system status."""
    running = sum(1 for a in automations.values() if a.status == AutomationStatus.RUNNING)
    paused = sum(1 for a in automations.values() if a.status == AutomationStatus.PAUSED)
    stopped = sum(1 for a in automations.values() if a.status == AutomationStatus.STOPPED)
    errors = sum(1 for a in automations.values() if a.status == AutomationStatus.ERROR)
    
    return JSONResponse({
        "system": {
            "uptime": str(datetime.now() - startup_time),
            "browser_ready": main_page is not None,
            "total_automations": len(automations),
            "running_automations": running,
            "paused_automations": paused,
            "stopped_automations": stopped,
            "error_automations": errors,
            "cookies_count": len(cookies),
            "last_update": datetime.now().isoformat()
        },
        "automations": [a.to_dict() for a in automations.values()]
    })

@app.post("/automation/create")
async def create_automation(request: Request):
    """Create a new automation."""
    try:
        data = await request.json()
        url = data.get("url", "").strip()
        name = data.get("name", f"Automation-{len(automations)+1}")
        interval = data.get("interval_minutes", 5)
        
        if not url:
            return JSONResponse({"success": False, "error": "No URL provided"})
        
        # Ensure URL has protocol
        if not url.startswith(("http://", "https://")):
            url = "https://" + url
        
        automation_id = str(uuid.uuid4())[:8]
        automation = Automation(
            id=automation_id,
            url=url,
            name=name,
            status=AutomationStatus.STOPPED,
            created_at=datetime.now(),
            last_run=None,
            total_runs=0,
            interval_minutes=interval,
            next_run=None
        )
        
        automations[automation_id] = automation
        
        logger.info(f"✅ Created automation {automation_id}: {name} for {url}")
        
        return JSONResponse({
            "success": True,
            "automation": automation.to_dict(),
            "message": f"Automation '{name}' created successfully"
        })
        
    except Exception as e:
        logger.error(f"❌ Create automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/{automation_id}/start")
async def start_automation(automation_id: str):
    """Start an automation."""
    try:
        automation = automations.get(automation_id)
        if not automation:
            return JSONResponse({"success": False, "error": "Automation not found"})
        
        if automation.status == AutomationStatus.RUNNING:
            return JSONResponse({"success": False, "error": "Automation already running"})
        
        automation.status = AutomationStatus.RUNNING
        
        # Start worker in background
        asyncio.create_task(automation_worker(automation_id))
        
        logger.info(f"▶️ Started automation {automation_id}: {automation.name}")
        
        return JSONResponse({
            "success": True,
            "automation": automation.to_dict(),
            "message": f"Automation '{automation.name}' started"
        })
        
    except Exception as e:
        logger.error(f"❌ Start automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/{automation_id}/stop")
async def stop_automation(automation_id: str):
    """Stop an automation."""
    try:
        automation = automations.get(automation_id)
        if not automation:
            return JSONResponse({"success": False, "error": "Automation not found"})
        
        if automation.status != AutomationStatus.RUNNING:
            return JSONResponse({"success": False, "error": "Automation not running"})
        
        automation.status = AutomationStatus.STOPPED
        
        logger.info(f"⏹️ Stopped automation {automation_id}: {automation.name}")
        
        return JSONResponse({
            "success": True,
            "automation": automation.to_dict(),
            "message": f"Automation '{automation.name}' stopped"
        })
        
    except Exception as e:
        logger.error(f"❌ Stop automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/{automation_id}/pause")
async def pause_automation(automation_id: str):
    """Pause an automation."""
    try:
        automation = automations.get(automation_id)
        if not automation:
            return JSONResponse({"success": False, "error": "Automation not found"})
        
        if automation.status != AutomationStatus.RUNNING:
            return JSONResponse({"success": False, "error": "Automation not running"})
        
        automation.status = AutomationStatus.PAUSED
        
        logger.info(f"⏸️ Paused automation {automation_id}: {automation.name}")
        
        return JSONResponse({
            "success": True,
            "automation": automation.to_dict(),
            "message": f"Automation '{automation.name}' paused"
        })
        
    except Exception as e:
        logger.error(f"❌ Pause automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/{automation_id}/resume")
async def resume_automation(automation_id: str):
    """Resume a paused automation."""
    try:
        automation = automations.get(automation_id)
        if not automation:
            return JSONResponse({"success": False, "error": "Automation not found"})
        
        if automation.status != AutomationStatus.PAUSED:
            return JSONResponse({"success": False, "error": "Automation not paused"})
        
        automation.status = AutomationStatus.RUNNING
        
        logger.info(f"▶️ Resumed automation {automation_id}: {automation.name}")
        
        return JSONResponse({
            "success": True,
            "automation": automation.to_dict(),
            "message": f"Automation '{automation.name}' resumed"
        })
        
    except Exception as e:
        logger.error(f"❌ Resume automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.delete("/automation/{automation_id}")
async def delete_automation(automation_id: str):
    """Delete an automation."""
    try:
        automation = automations.get(automation_id)
        if not automation:
            return JSONResponse({"success": False, "error": "Automation not found"})
        
        # Stop if running
        if automation.status == AutomationStatus.RUNNING:
            automation.status = AutomationStatus.STOPPED
        
        # Remove from dictionary
        del automations[automation_id]
        
        logger.info(f"🗑️ Deleted automation {automation_id}: {automation.name}")
        
        return JSONResponse({
            "success": True,
            "message": f"Automation '{automation.name}' deleted"
        })
        
    except Exception as e:
        logger.error(f"❌ Delete automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/batch/start")
async def start_all_automations():
    """Start all automations."""
    try:
        started = 0
        for automation_id, automation in automations.items():
            if automation.status != AutomationStatus.RUNNING:
                automation.status = AutomationStatus.RUNNING
                asyncio.create_task(automation_worker(automation_id))
                started += 1
        
        logger.info(f"▶️ Started {started} automations")
        
        return JSONResponse({
            "success": True,
            "started": started,
            "message": f"Started {started} automations"
        })
        
    except Exception as e:
        logger.error(f"❌ Start all automations error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/batch/stop")
async def stop_all_automations():
    """Stop all automations."""
    try:
        stopped = 0
        for automation in automations.values():
            if automation.status == AutomationStatus.RUNNING:
                automation.status = AutomationStatus.STOPPED
                stopped += 1
        
        logger.info(f"⏹️ Stopped {stopped} automations")
        
        return JSONResponse({
            "success": True,
            "stopped": stopped,
            "message": f"Stopped {stopped} automations"
        })
        
    except Exception as e:
        logger.error(f"❌ Stop all automations error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/load")
async def load_url(request: Request):
    """Load a URL in the main browser."""
    try:
        data = await request.json()
        url = data.get("url", "").strip()
        
        if not url:
            return JSONResponse({"success": False, "error": "No URL provided"})
        
        if not main_page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        logger.info(f"🌐 Main browser: Loading URL: {url}")
        
        # Ensure URL has protocol
        if not url.startswith(("http://", "https://")):
            url = "https://" + url
        
        # Navigate to URL
        try:
            await main_page.goto(url, wait_until="domcontentloaded", timeout=60000)
        except Exception as nav_error:
            logger.warning(f"Navigation had issues but continuing: {nav_error}")
        
        logger.info(f"✅ Main browser: Loaded: {url}")
        
        return JSONResponse({
            "success": True,
            "url": url,
            "message": "URL loaded successfully"
        })
        
    except Exception as e:
        logger.error(f"❌ Load URL error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/screenshot")
async def get_screenshot():
    """Take screenshot of main browser."""
    try:
        if not main_page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        filename = await take_screenshot("main")
        if filename:
            return JSONResponse({
                "success": True,
                "filename": filename,
                "url": f"/screenshots/{filename}"
            })
        else:
            return JSONResponse({"success": False, "error": "Failed to take screenshot"})
            
    except Exception as e:
        logger.error(f"❌ Screenshot error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/screenshots/{filename}")
async def serve_screenshot(filename: str):
    """Serve screenshot file."""
    filepath = os.path.join("screenshots", filename)
    if os.path.exists(filepath):
        return FileResponse(filepath, media_type="image/png")
    raise HTTPException(status_code=404, detail="Screenshot not found")

@app.post("/cookies/refresh")
async def refresh_cookies():
    """Refresh cookies."""
    try:
        success = await download_cookies()
        
        if success and cookies and main_context:
            # Clear old cookies and add new ones
            await main_context.clear_cookies()
            await main_context.add_cookies(cookies)
            
            # Reload main page
            if main_page:
                await main_page.reload()
            
            logger.info(f"🔄 Refreshed {len(cookies)} cookies")
            
            return JSONResponse({
                "success": True,
                "cookies_count": len(cookies),
                "message": f"Refreshed {len(cookies)} cookies"
            })
        else:
            return JSONResponse({"success": False, "error": "Failed to download cookies"})
            
    except Exception as e:
        logger.error(f"❌ Refresh cookies error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/browser/back")
async def browser_back():
    """Go back in browser history."""
    try:
        if not main_page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        await main_page.go_back()
        logger.info("🔙 Browser: Went back")
        
        return JSONResponse({"success": True, "message": "Went back"})
    except Exception as e:
        logger.error(f"❌ Browser back error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/browser/forward")
async def browser_forward():
    """Go forward in browser history."""
    try:
        if not main_page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        await main_page.go_forward()
        logger.info("🔜 Browser: Went forward")
        
        return JSONResponse({"success": True, "message": "Went forward"})
    except Exception as e:
        logger.error(f"❌ Browser forward error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/browser/reload")
async def browser_reload():
    """Reload current page."""
    try:
        if not main_page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        await main_page.reload()
        logger.info("🔄 Browser: Reloaded page")
        
        return JSONResponse({"success": True, "message": "Page reloaded"})
    except Exception as e:
        logger.error(f"❌ Browser reload error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    running = sum(1 for a in automations.values() if a.status == AutomationStatus.RUNNING)
    
    return JSONResponse({
        "status": "healthy",
        "browser_ready": main_page is not None,
        "total_automations": len(automations),
        "running_automations": running,
        "uptime": str(datetime.now() - startup_time),
        "timestamp": datetime.now().isoformat()
    })

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
EOF

# Create the JavaScript file separately due to length
RUN cat > templates/script.js << 'EOF'
// Complete JavaScript for multi-automation dashboard
document.addEventListener('DOMContentLoaded', () => {
    // State
    let automations = [];
    let systemStatus = {};
    let logs = [];
    let autoScroll = true;
    let currentTab = 'automations';
    let startupTime = new Date();
    
    // DOM Elements
    const elements = {
        // Tabs
        tabButtons: document.querySelectorAll('.tab-btn'),
        tabContents: document.querySelectorAll('.tab-content'),
        
        // Automation creation
        newAutomationUrl: document.getElementById('newAutomationUrl'),
        createAutomationBtn: document.getElementById('createAutomationBtn'),
        addFromCurrentBtn: document.getElementById('addFromCurrentBtn'),
        
        // Batch controls
        startAllBtn: document.getElementById('startAllBtn'),
        stopAllBtn: document.getElementById('stopAllBtn'),
        pauseAllBtn: document.getElementById('pauseAllBtn'),
        refreshAllBtn: document.getElementById('refreshAllBtn'),
        
        // Browser controls
        browserUrl: document.getElementById('browserUrl'),
        browserGoBtn: document.getElementById('browserGoBtn'),
        browserScreenshotBtn: document.getElementById('browserScreenshotBtn'),
        browserBackBtn: document.getElementById('browserBackBtn'),
        browserForwardBtn: document.getElementById('browserForwardBtn'),
        browserReloadBtn: document.getElementById('browserReloadBtn'),
        browserHomeBtn: document.getElementById('browserHomeBtn'),
        refreshCookiesBtn: document.getElementById('refreshCookiesBtn'),
        clearCookiesBtn: document.getElementById('clearCookiesBtn'),
        
        // Screenshots
        takeScreenshotBtn: document.getElementById('takeScreenshotBtn'),
        downloadScreenshotBtn: document.getElementById('downloadScreenshotBtn'),
        screenshotImage: document.getElementById('screenshotImage'),
        screenshotPlaceholder: document.getElementById('screenshotPlaceholder'),
        recentScreenshots: document.getElementById('recentScreenshots'),
        
        // Logs
        logBox: document.getElementById('logBox'),
        clearLogsBtn: document.getElementById('clearLogsBtn'),
        exportLogsBtn: document.getElementById('exportLogsBtn'),
        autoScrollBtn: document.getElementById('autoScrollBtn'),
        
        // Status displays
        totalAutomations: document.getElementById('totalAutomations'),
        runningAutomations: document.getElementById('runningAutomations'),
        pausedAutomations: document.getElementById('pausedAutomations'),
        automationList: document.getElementById('automationList'),
        browserCurrentUrl: document.getElementById('browserCurrentUrl'),
        browserCookiesStatus: document.getElementById('browserCookiesStatus'),
        browserSessionStatus: document.getElementById('browserSessionStatus'),
        statusTotal: document.getElementById('statusTotal'),
        statusActive: document.getElementById('statusActive'),
        statusUptime: document.getElementById('statusUptime'),
        statusLastUpdate: document.getElementById('statusLastUpdate'),
        
        // Quick actions
        quickStartBtn: document.getElementById('quickStartBtn'),
        quickStopBtn: document.getElementById('quickStopBtn'),
        refreshStatusBtn: document.getElementById('refreshStatusBtn'),
        
        // Loading
        loadingOverlay: document.getElementById('loadingOverlay'),
        loadingText: document.getElementById('loadingText'),
        
        // Notification
        notification: document.getElementById('notification'),
        
        // Modal
        automationModal: document.getElementById('automationModal'),
        modalContent: document.getElementById('modalContent'),
        closeModalBtn: document.getElementById('closeModalBtn')
    };
    
    // Initialize
    init();
    
    // Functions
    function init() {
        // Load saved state
        loadSavedState();
        
        // Set up event listeners
        setupEventListeners();
        
        // Start polling
        startPolling();
        
        // Initial status update
        updateStatus();
        
        addLog('Dashboard initialized', 'info');
        showNotification('Multi-automation dashboard ready', 'success', 2000);
    }
    
    function loadSavedState() {
        try {
            const saved = localStorage.getItem('automationDashboardState');
            if (saved) {
                const state = JSON.parse(saved);
                if (state.currentTab) {
                    switchTab(state.currentTab);
                }
                if (state.logs) {
                    logs = state.logs.slice(-100);
                    updateLogDisplay();
                }
            }
        } catch (e) {
            console.error('Error loading saved state:', e);
        }
    }
    
    function saveState() {
        try {
            const state = {
                currentTab: currentTab,
                logs: logs.slice(-100)
            };
            localStorage.setItem('automationDashboardState', JSON.stringify(state));
        } catch (e) {
            console.error('Error saving state:', e);
        }
    }
    
    function setupEventListeners() {
        // Tab switching
        elements.tabButtons.forEach(btn => {
            btn.addEventListener('click', () => {
                const tab = btn.getAttribute('data-tab');
                switchTab(tab);
            });
        });
        
        // Automation creation
        elements.createAutomationBtn.addEventListener('click', createAutomation);
        elements.addFromCurrentBtn.addEventListener('click', addFromCurrent);
        
        // Batch controls
        elements.startAllBtn.addEventListener('click', startAllAutomations);
        elements.stopAllBtn.addEventListener('click', stopAllAutomations);
        elements.pauseAllBtn.addEventListener('click', pauseAllAutomations);
        elements.refreshAllBtn.addEventListener('click', refreshAllAutomations);
        
        // Browser controls
        elements.browserGoBtn.addEventListener('click', browserGo);
        elements.browserScreenshotBtn.addEventListener('click', takeBrowserScreenshot);
        elements.browserBackBtn.addEventListener('click', browserBack);
        elements.browserForwardBtn.addEventListener('click', browserForward);
        elements.browserReloadBtn.addEventListener('click', browserReload);
        elements.browserHomeBtn.addEventListener('click', browserHome);
        elements.refreshCookiesBtn.addEventListener('click', refreshCookies);
        elements.clearCookiesBtn.addEventListener('click', clearCookies);
        
        // Screenshots
        elements.takeScreenshotBtn.addEventListener('click', takeBrowserScreenshot);
        elements.downloadScreenshotBtn.addEventListener('click', downloadScreenshot);
        
        // Logs
        elements.clearLogsBtn.addEventListener('click', clearLogs);
        elements.exportLogsBtn.addEventListener('click', exportLogs);
        elements.autoScrollBtn.addEventListener('click', toggleAutoScroll);
        
        // Quick actions
        elements.quickStartBtn.addEventListener('click', quickStart);
        elements.quickStopBtn.addEventListener('click', quickStop);
        elements.refreshStatusBtn.addEventListener('click', updateStatus);
        
        // Modal
        elements.closeModalBtn.addEventListener('click', () => {
            elements.automationModal.style.display = 'none';
        });
        
        // Keyboard shortcuts
        document.addEventListener('keydown', handleKeyboardShortcuts);
    }
    
    function switchTab(tabName) {
        currentTab = tabName;
        saveState();
        
        // Update tab buttons
        elements.tabButtons.forEach(btn => {
            if (btn.getAttribute('data-tab') === tabName) {
                btn.classList.add('active');
            } else {
                btn.classList.remove('active');
            }
        });
        
        // Update tab contents
        elements.tabContents.forEach(content => {
            if (content.id === `${tabName}-tab`) {
                content.classList.add('active');
            } else {
                content.classList.remove('active');
            }
        });
        
        addLog(`Switched to ${tabName} tab`, 'info');
    }
    
    async function updateStatus() {
        try {
            const response = await fetch('/status');
            const data = await response.json();
            
            systemStatus = data.system;
            automations = data.automations || [];
            
            // Update stats
            elements.totalAutomations.textContent = systemStatus.total_automations;
            elements.runningAutomations.textContent = systemStatus.running_automations;
            elements.pausedAutomations.textContent = systemStatus.paused_automations;
            
            // Update system status
            elements.statusTotal.textContent = systemStatus.total_automations;
            elements.statusActive.textContent = systemStatus.running_automations;
            elements.statusUptime.textContent = formatUptime(systemStatus.uptime);
            elements.statusLastUpdate.textContent = new Date().toLocaleTimeString();
            elements.statusLastUpdate.style.color = '#666';
            
            // Update automation list
            updateAutomationList();
            
            // Update browser status
            if (systemStatus.browser_ready) {
                elements.browserSessionStatus.textContent = 'Active';
                elements.browserSessionStatus.style.color = '#2ed573';
            } else {
                elements.browserSessionStatus.textContent = 'Not Ready';
                elements.browserSessionStatus.style.color = '#ff4757';
            }
            
            // Update cookies status
            const cookiesCount = systemStatus.cookies_count || 0;
            elements.browserCookiesStatus.innerHTML = `
                ${cookiesCount} cookies loaded
                <span style="margin-left: 5px;">${cookiesCount > 0 ? '✅' : '❌'}</span>
            `;
            
        } catch (error) {
            console.error('Failed to update status:', error);
            addLog(`Status update failed: ${error.message}`, 'error');
        }
    }
    
    function updateAutomationList() {
        const list = elements.automationList;
        
        if (automations.length === 0) {
            list.innerHTML = `
                <div class="no-automations">
                    <i class="fas fa-robot fa-3x" style="color: #ddd; margin-bottom: 15px;"></i><br>
                    No automations yet. Create one above!
                </div>
            `;
            return;
        }
        
        list.innerHTML = '';
        
        automations.forEach(automation => {
            const item = document.createElement('div');
            item.className = `automation-item ${automation.status}`;
            
            const statusClass = `status-${automation.status}`;
            const statusIcon = automation.status === 'running' ? '▶️' : 
                              automation.status === 'paused' ? '⏸️' : '⏹️';
            
            item.innerHTML = `
                <div class="automation-header">
                    <div class="automation-title" title="${automation.name}">
                        ${statusIcon} ${automation.name}
                    </div>
                    <span class="automation-status ${statusClass}">
                        ${automation.status.toUpperCase()}
                    </span>
                </div>
                <div class="automation-url" title="${automation.url}">
                    ${automation.url.length > 60 ? automation.url.substring(0, 60) + '...' : automation.url}
                </div>
                <div class="automation-controls-small">
                    ${automation.status === 'running' ? `
                        <button class="btn btn-danger btn-sm" onclick="pauseAutomation('${automation.id}')">
                            <i class="fas fa-pause"></i> Pause
                        </button>
                        <button class="btn btn-warning btn-sm" onclick="stopAutomation('${automation.id}')">
                            <i class="fas fa-stop"></i> Stop
                        </button>
                    ` : automation.status === 'paused' ? `
                        <button class="btn btn-success btn-sm" onclick="resumeAutomation('${automation.id}')">
                            <i class="fas fa-play"></i> Resume
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="stopAutomation('${automation.id}')">
                            <i class="fas fa-stop"></i> Stop
                        </button>
                    ` : `
                        <button class="btn btn-success btn-sm" onclick="startAutomation('${automation.id}')">
                            <i class="fas fa-play"></i> Start
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="deleteAutomation('${automation.id}')">
                            <i class="fas fa-trash"></i> Delete
                        </button>
                    `}
                    <button class="btn btn-secondary btn-sm" onclick="showAutomationDetails('${automation.id}')">
                        <i class="fas fa-info"></i> Details
                    </button>
                </div>
                <div class="automation-info">
                    <span>Runs: ${automation.total_runs}</span>
                    <span>Interval: ${automation.interval_minutes}m</span>
                </div>
            `;
            
            list.appendChild(item);
        });
    }
    
    async function createAutomation() {
        const url = elements.newAutomationUrl.value.trim();
        if (!url) {
            showNotification('Please enter a URL', 'error');
            return;
        }
        
        showLoading('Creating automation...');
        
        try {
            const response = await fetch('/automation/create', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ 
                    url: url,
                    name: `Automation-${automations.length + 1}`,
                    interval_minutes: 5
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Created automation: ${data.automation.name}`, 'success');
                showNotification('Automation created successfully', 'success');
                elements.newAutomationUrl.value = '';
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to create automation');
            }
        } catch (error) {
            addLog(`Failed to create automation: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function addFromCurrent() {
        // This would use the current browser URL
        // For now, we'll just use a placeholder
        showNotification('Feature coming soon', 'info');
    }
    
    async function startAutomation(id) {
        showLoading('Starting automation...');
        
        try {
            const response = await fetch(`/automation/${id}/start`, {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Started automation: ${data.automation.name}`, 'success');
                showNotification('Automation started', 'success');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to start automation');
            }
        } catch (error) {
            addLog(`Failed to start automation: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function stopAutomation(id) {
        showLoading('Stopping automation...');
        
        try {
            const response = await fetch(`/automation/${id}/stop`, {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Stopped automation: ${data.automation.name}`, 'success');
                showNotification('Automation stopped', 'info');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to stop automation');
            }
        } catch (error) {
            addLog(`Failed to stop automation: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function pauseAutomation(id) {
        showLoading('Pausing automation...');
        
        try {
            const response = await fetch(`/automation/${id}/pause`, {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Paused automation: ${data.automation.name}`, 'success');
                showNotification('Automation paused', 'warning');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to pause automation');
            }
        } catch (error) {
            addLog(`Failed to pause automation: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function resumeAutomation(id) {
        showLoading('Resuming automation...');
        
        try {
            const response = await fetch(`/automation/${id}/resume`, {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Resumed automation: ${data.automation.name}`, 'success');
                showNotification('Automation resumed', 'success');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to resume automation');
            }
        } catch (error) {
            addLog(`Failed to resume automation: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function deleteAutomation(id) {
        if (!confirm('Are you sure you want to delete this automation?')) {
            return;
        }
        
        showLoading('Deleting automation...');
        
        try {
            const response = await fetch(`/automation/${id}`, {
                method: 'DELETE'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Deleted automation`, 'success');
                showNotification('Automation deleted', 'info');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to delete automation');
            }
        } catch (error) {
            addLog(`Failed to delete automation: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function startAllAutomations() {
        showLoading('Starting all automations...');
        
        try {
            const response = await fetch('/automation/batch/start', {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Started ${data.started} automations`, 'success');
                showNotification(`Started ${data.started} automations`, 'success');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to start automations');
            }
        } catch (error) {
            addLog(`Failed to start all automations: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function stopAllAutomations() {
        showLoading('Stopping all automations...');
        
        try {
            const response = await fetch('/automation/batch/stop', {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Stopped ${data.stopped} automations`, 'success');
                showNotification(`Stopped ${data.stopped} automations`, 'info');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to stop automations');
            }
        } catch (error) {
            addLog(`Failed to stop all automations: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function pauseAllAutomations() {
        // This would pause all running automations
        // Implementation would be similar to stopAllAutomations
        showNotification('Feature coming soon', 'info');
    }
    
    async function refreshAllAutomations() {
        // This would refresh all automations
        showNotification('Feature coming soon', 'info');
    }
    
    async function browserGo() {
        const url = elements.browserUrl.value.trim();
        if (!url) {
            showNotification('Please enter a URL', 'error');
            return;
        }
        
        showLoading(`Loading ${url}...`);
        
        try {
            const response = await fetch('/load', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url: url })
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Browser navigated to: ${url}`, 'info');
                showNotification('URL loaded successfully', 'success');
                elements.browserCurrentUrl.textContent = url;
                await takeBrowserScreenshot();
            } else {
                throw new Error(data.error || 'Failed to load URL');
            }
        } catch (error) {
            addLog(`Failed to load URL: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function takeBrowserScreenshot() {
        showLoading('Taking screenshot...');
        
        try {
            const response = await fetch('/screenshot');
            const data = await response.json();
            
            if (data.success) {
                elements.screenshotImage.src = `/screenshots/${data.filename}?t=${Date.now()}`;
                elements.screenshotImage.style.display = 'block';
                elements.screenshotPlaceholder.style.display = 'none';
                
                addLog('Screenshot taken', 'success');
                showNotification('Screenshot updated', 'success');
            } else {
                throw new Error(data.error || 'Failed to take screenshot');
            }
        } catch (error) {
            addLog(`Screenshot failed: ${error.message}`, 'error');
            showNotification(`Screenshot error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function browserBack() {
        try {
            const response = await fetch('/browser/back', {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog('Browser: Went back', 'info');
                showNotification('Went back', 'info');
                await updateStatus();
            }
        } catch (error) {
            addLog(`Failed to go back: ${error.message}`, 'error');
        }
    }
    
    async function browserForward() {
        try {
            const response = await fetch('/browser/forward', {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog('Browser: Went forward', 'info');
                showNotification('Went forward', 'info');
                await updateStatus();
            }
        } catch (error) {
            addLog(`Failed to go forward: ${error.message}`, 'error');
        }
    }
    
    async function browserReload() {
        try {
            const response = await fetch('/browser/reload', {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog('Browser: Reloaded page', 'info');
                showNotification('Page reloaded', 'info');
                await updateStatus();
            }
        } catch (error) {
            addLog(`Failed to reload: ${error.message}`, 'error');
        }
    }
    
    async function browserHome() {
        elements.browserUrl.value = 'https://www.google.com';
        await browserGo();
    }
    
    async function refreshCookies() {
        showLoading('Refreshing cookies...');
        
        try {
            const response = await fetch('/cookies/refresh', {
                method: 'POST'
            });
            
            const data = await response.json();
            
            if (data.success) {
                addLog(`Refreshed ${data.cookies_count} cookies`, 'success');
                showNotification('Cookies refreshed successfully', 'success');
                await updateStatus();
            } else {
                throw new Error(data.error || 'Failed to refresh cookies');
            }
        } catch (error) {
            addLog(`Failed to refresh cookies: ${error.message}`, 'error');
            showNotification(`Error: ${error.message}`, 'error');
        } finally {
            hideLoading();
        }
    }
    
    async function clearCookies() {
        if (!confirm('Are you sure you want to clear all cookies?')) {
            return;
        }
        
        showNotification('Feature coming soon', 'info');
    }
    
    function downloadScreenshot() {
        const img = elements.screenshotImage;
        if (img.src && img.style.display !== 'none') {
            const link = document.createElement('a');
            link.href = img.src;
            link.download = `screenshot_${Date.now()}.png`;
            link.click();
            addLog('Screenshot downloaded', 'success');
        } else {
            showNotification('No screenshot available to download', 'error');
        }
    }
    
    function addLog(message, type = 'info') {
        const timestamp = new Date().toLocaleTimeString();
        const logEntry = {
            time: timestamp,
            message: message,
            type: type
        };
        
        logs.push(logEntry);
        
        // Update display
        updateLogDisplay();
        
        // Save to localStorage
        saveState();
    }
    
    function updateLogDisplay() {
        const logBox = elements.logBox;
        logBox.innerHTML = '';
        
        logs.slice(-100).forEach(log => {
            const entry = document.createElement('div');
            entry.className = 'log-entry';
            entry.innerHTML = `
                <span class="log-time">[${log.time}]</span>
                <span class="log-${log.type}"> ${log.message}</span>
            `;
            logBox.appendChild(entry);
        });
        
        if (autoScroll) {
            logBox.scrollTop = logBox.scrollHeight;
        }
    }
    
    function clearLogs() {
        if (!confirm('Are you sure you want to clear all logs?')) {
            return;
        }
        
        logs = [];
        updateLogDisplay();
        addLog('Logs cleared', 'info');
        showNotification('Logs cleared', 'info');
    }
    
    function exportLogs() {
        const logText = logs.map(log => `[${log.time}] ${log.message}`).join('\n');
        const blob = new Blob([logText], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `automation_logs_${Date.now()}.txt`;
        link.click();
        URL.revokeObjectURL(url);
        addLog('Logs exported', 'success');
    }
    
    function toggleAutoScroll() {
        autoScroll = !autoScroll;
        const btn = elements.autoScrollBtn;
        if (autoScroll) {
            btn.innerHTML = '<i class="fas fa-arrow-down"></i> Auto-scroll: ON';
            btn.className = 'btn btn-success';
        } else {
            btn.innerHTML = '<i class="fas fa-arrow-down"></i> Auto-scroll: OFF';
            btn.className = 'btn btn-secondary';
        }
    }
    
    function quickStart() {
        // Quick start - create and start an automation with current URL
        const url = elements.browserUrl.value.trim() || elements.newAutomationUrl.value.trim();
        if (url) {
            elements.newAutomationUrl.value = url;
            createAutomation().then(() => {
                // Start the newly created automation
                if (automations.length > 0) {
                    const lastAutomation = automations[automations.length - 1];
                    startAutomation(lastAutomation.id);
                }
            });
        } else {
            showNotification('Please enter a URL first', 'error');
        }
    }
    
    function quickStop() {
        stopAllAutomations();
    }
    
    function showAutomationDetails(id) {
        const automation = automations.find(a => a.id === id);
        if (!automation) return;
        
        elements.modalContent.innerHTML = `
            <div style="margin-bottom: 15px;">
                <strong>Name:</strong> ${automation.name}<br>
                <strong>Status:</strong> ${automation.status.toUpperCase()}<br>
                <strong>Created:</strong> ${new Date(automation.created_at).toLocaleString()}<br>
                <strong>Total Runs:</strong> ${automation.total_runs}<br>
                <strong>Interval:</strong> ${automation.interval_minutes} minutes<br>
                ${automation.last_run ? `<strong>Last Run:</strong> ${new Date(automation.last_run).toLocaleString()}<br>` : ''}
                ${automation.next_run ? `<strong>Next Run:</strong> ${new Date(automation.next_run).toLocaleString()}<br>` : ''}
            </div>
            <div style="margin-bottom: 15px;">
                <strong>URL:</strong><br>
                <div style="background: #f5f5f5; padding: 10px; border-radius: 5px; margin-top: 5px; font-size: 12px; word-break: break-all;">
                    ${automation.url}
                </div>
            </div>
        `;
        
        elements.automationModal.style.display = 'flex';
    }
    
    function showLoading(text = 'Processing...') {
        elements.loadingText.textContent = text;
        elements.loadingOverlay.style.display = 'block';
    }
    
    function hideLoading() {
        elements.loadingOverlay.style.display = 'none';
    }
    
    function showNotification(message, type = 'info', duration = 3000) {
        const notification = elements.notification;
        notification.textContent = message;
        notification.className = `notification ${type}`;
        notification.style.display = 'block';
        
        setTimeout(() => {
            notification.style.display = 'none';
        }, duration);
    }
    
    function formatUptime(uptimeStr) {
        // Parse uptime string like "0:01:23.456789"
        if (!uptimeStr) return '00:00:00';
        
        try {
            const parts = uptimeStr.split(':');
            if (parts.length >= 3) {
                const hours = parts[0].padStart(2, '0');
                const minutes = parts[1].padStart(2, '0');
                const seconds = Math.floor(parseFloat(parts[2])).toString().padStart(2, '0');
                return `${hours}:${minutes}:${seconds}`;
            }
        } catch (e) {
            console.error('Error formatting uptime:', e);
        }
        
        return uptimeStr;
    }
    
    function handleKeyboardShortcuts(e) {
        // Ctrl+Enter to quick start
        if (e.ctrlKey && e.key === 'Enter') {
            e.preventDefault();
            quickStart();
        }
        
        // Escape to close modal
        if (e.key === 'Escape' && elements.automationModal.style.display === 'flex') {
            elements.automationModal.style.display = 'none';
        }
    }
    
    function startPolling() {
        // Update status every 5 seconds
        setInterval(updateStatus, 5000);
        
        // Update uptime every second
        setInterval(() => {
            if (systemStatus.uptime) {
                elements.statusUptime.textContent = formatUptime(systemStatus.uptime);
            }
            elements.statusLastUpdate.textContent = new Date().toLocaleTimeString();
            elements.statusLastUpdate.style.color = '#666';
        }, 1000);
    }
    
    // Make functions available globally for onclick handlers
    window.startAutomation = startAutomation;
    window.stopAutomation = stopAutomation;
    window.pauseAutomation = pauseAutomation;
    window.resumeAutomation = resumeAutomation;
    window.deleteAutomation = deleteAutomation;
    window.showAutomationDetails = showAutomationDetails;
});
EOF

# Create directories
RUN mkdir -p /app/screenshots /app/static

# Expose port
EXPOSE 8000

# Run the web server
CMD ["python", "main.py"]
