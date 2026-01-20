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

# Create HTML template
RUN mkdir -p templates && cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>🤖 Colab Automation Dashboard</title>
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
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .dashboard {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-top: 20px;
        }
        
        @media (max-width: 768px) {
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
        
        .url-input-group {
            margin-bottom: 20px;
        }
        
        .url-input {
            width: 100%;
            padding: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
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
            gap: 15px;
            margin-bottom: 25px;
        }
        
        .btn {
            padding: 15px 25px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
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
        
        .btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
            transform: none !important;
        }
        
        .status-card {
            margin-top: 20px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 5px solid #667eea;
        }
        
        .status-title {
            font-weight: 600;
            margin-bottom: 5px;
            color: #333;
        }
        
        .status-value {
            color: #666;
            font-family: monospace;
        }
        
        .log-box {
            background: #1e1e1e;
            color: #00ff00;
            padding: 20px;
            border-radius: 8px;
            font-family: 'Courier New', monospace;
            font-size: 14px;
            height: 300px;
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
        
        .loading {
            display: none;
            text-align: center;
            padding: 20px;
        }
        
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #667eea;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 15px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .notification {
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 15px 25px;
            border-radius: 8px;
            color: white;
            font-weight: 600;
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
        
        .automation-controls {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }
        
        .cookie-status {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            margin-left: 10px;
        }
        
        .cookie-good {
            background: #2ed573;
            color: white;
        }
        
        .cookie-bad {
            background: #ff4757;
            color: white;
        }
    </style>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
</head>
<body>
    <div class="container">
        <h1><i class="fas fa-robot"></i> Colab Automation Dashboard</h1>
        <p class="subtitle">Automate Google Colab with persistent browser session</p>
        
        <div class="dashboard">
            <!-- Left Column -->
            <div>
                <!-- URL Input Card -->
                <div class="card">
                    <h2><i class="fas fa-link"></i> Colab URL</h2>
                    <div class="url-input-group">
                        <input type="url" 
                               id="colabUrl" 
                               class="url-input" 
                               placeholder="https://colab.research.google.com/drive/..."
                               value="https://colab.research.google.com/">
                    </div>
                    
                    <div class="button-group">
                        <button id="loadUrlBtn" class="btn btn-primary">
                            <i class="fas fa-external-link-alt"></i> Load URL
                        </button>
                        <button id="getScreenshotBtn" class="btn btn-secondary">
                            <i class="fas fa-camera"></i> Screenshot
                        </button>
                    </div>
                    
                    <div class="automation-controls">
                        <button id="startAutomationBtn" class="btn btn-success">
                            <i class="fas fa-play"></i> Start Automation
                        </button>
                        <button id="stopAutomationBtn" class="btn btn-danger">
                            <i class="fas fa-stop"></i> Stop
                        </button>
                        <button id="refreshCookiesBtn" class="btn btn-secondary">
                            <i class="fas fa-redo"></i> Refresh Cookies
                        </button>
                        <button id="restoreBtn" class="btn btn-secondary">
                            <i class="fas fa-home"></i> Restore Google.com
                        </button>
                    </div>
                </div>
                
                <!-- Status Card -->
                <div class="card">
                    <h2><i class="fas fa-info-circle"></i> Status</h2>
                    <div class="status-card">
                        <div class="status-title">Current URL</div>
                        <div id="currentUrl" class="status-value">Loading...</div>
                    </div>
                    <div class="status-card">
                        <div class="status-title">Automation Status</div>
                        <div id="automationStatus" class="status-value">Stopped</div>
                    </div>
                    <div class="status-card">
                        <div class="status-title">Cookies</div>
                        <div id="cookiesStatus" class="status-value">
                            <span id="cookiesCount">0</span> cookies loaded
                            <span id="cookiesIndicator" class="cookie-status cookie-bad">❌</span>
                        </div>
                    </div>
                    <div class="status-card">
                        <div class="status-title">Last Action</div>
                        <div id="lastAction" class="status-value">-</div>
                    </div>
                </div>
            </div>
            
            <!-- Right Column -->
            <div>
                <!-- Screenshot Card -->
                <div class="card">
                    <h2><i class="fas fa-image"></i> Live Screenshot</h2>
                    <div class="screenshot-container">
                        <div id="screenshotPlaceholder" class="no-screenshot">
                            <i class="fas fa-image fa-3x" style="color: #ddd; margin-bottom: 15px;"></i><br>
                            No screenshot yet
                        </div>
                        <img id="screenshotImage" class="screenshot-img" style="display: none;" alt="Live Screenshot">
                    </div>
                </div>
                
                <!-- Logs Card -->
                <div class="card">
                    <h2><i class="fas fa-terminal"></i> Activity Logs</h2>
                    <div class="log-box" id="logBox">
                        <div class="log-entry">
                            <span class="log-time">[System]</span>
                            <span class="log-info"> Dashboard initialized</span>
                        </div>
                    </div>
                    <button id="clearLogsBtn" class="btn btn-secondary" style="margin-top: 15px;">
                        <i class="fas fa-trash"></i> Clear Logs
                    </button>
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
    
    <script>
        // State
        let automationRunning = false;
        let currentUrl = 'https://www.google.com';
        let logs = [];
        
        // DOM Elements
        const colabUrlInput = document.getElementById('colabUrl');
        const loadUrlBtn = document.getElementById('loadUrlBtn');
        const getScreenshotBtn = document.getElementById('getScreenshotBtn');
        const startAutomationBtn = document.getElementById('startAutomationBtn');
        const stopAutomationBtn = document.getElementById('stopAutomationBtn');
        const refreshCookiesBtn = document.getElementById('refreshCookiesBtn');
        const restoreBtn = document.getElementById('restoreBtn');
        const clearLogsBtn = document.getElementById('clearLogsBtn');
        const currentUrlSpan = document.getElementById('currentUrl');
        const automationStatusSpan = document.getElementById('automationStatus');
        const cookiesCountSpan = document.getElementById('cookiesCount');
        const cookiesIndicator = document.getElementById('cookiesIndicator');
        const lastActionSpan = document.getElementById('lastAction');
        const screenshotImage = document.getElementById('screenshotImage');
        const screenshotPlaceholder = document.getElementById('screenshotPlaceholder');
        const logBox = document.getElementById('logBox');
        const loadingOverlay = document.getElementById('loadingOverlay');
        const loadingText = document.getElementById('loadingText');
        const notification = document.getElementById('notification');
        
        // Initialize
        updateStatus();
        fetchCookiesStatus();
        
        // Helper Functions
        function addLog(message, type = 'info') {
            const timestamp = new Date().toLocaleTimeString();
            const logEntry = document.createElement('div');
            logEntry.className = 'log-entry';
            logEntry.innerHTML = `
                <span class="log-time">[${timestamp}]</span>
                <span class="log-${type}"> ${message}</span>
            `;
            logBox.appendChild(logEntry);
            logBox.scrollTop = logBox.scrollHeight;
            
            // Keep only last 50 logs
            const entries = logBox.querySelectorAll('.log-entry');
            if (entries.length > 50) {
                entries[0].remove();
            }
            
            logs.push({ time: timestamp, message, type });
        }
        
        function showNotification(message, type = 'info', duration = 3000) {
            notification.textContent = message;
            notification.className = `notification ${type}`;
            notification.style.display = 'block';
            
            setTimeout(() => {
                notification.style.display = 'none';
            }, duration);
        }
        
        function showLoading(text = 'Processing...') {
            loadingText.textContent = text;
            loadingOverlay.style.display = 'block';
        }
        
        function hideLoading() {
            loadingOverlay.style.display = 'none';
        }
        
        function updateStatus() {
            currentUrlSpan.textContent = currentUrl;
            automationStatusSpan.textContent = automationRunning ? 'Running' : 'Stopped';
            automationStatusSpan.style.color = automationRunning ? '#2ed573' : '#ff4757';
            
            // Update button states
            startAutomationBtn.disabled = automationRunning;
            stopAutomationBtn.disabled = !automationRunning;
        }
        
        async function fetchCookiesStatus() {
            try {
                const response = await fetch('/status');
                const data = await response.json();
                
                cookiesCountSpan.textContent = data.cookies_count || 0;
                if (data.cookies_count > 0) {
                    cookiesIndicator.textContent = '✅';
                    cookiesIndicator.className = 'cookie-status cookie-good';
                } else {
                    cookiesIndicator.textContent = '❌';
                    cookiesIndicator.className = 'cookie-status cookie-bad';
                }
            } catch (error) {
                console.error('Failed to fetch cookies status:', error);
            }
        }
        
        // API Functions
        async function loadUrl() {
            const url = colabUrlInput.value.trim();
            if (!url) {
                showNotification('Please enter a URL', 'error');
                return;
            }
            
            showLoading(`Loading ${url}...`);
            
            try {
                const response = await fetch('/load', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ url })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    currentUrl = url;
                    updateStatus();
                    addLog(`Loaded URL: ${url}`, 'success');
                    showNotification('URL loaded successfully', 'success');
                    await takeScreenshot(); // Auto-screenshot after loading
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
        
        async function takeScreenshot() {
            showLoading('Taking screenshot...');
            
            try {
                const response = await fetch('/screenshot');
                const data = await response.json();
                
                if (data.success) {
                    screenshotImage.src = `/screenshots/${data.filename}?t=${Date.now()}`;
                    screenshotImage.style.display = 'block';
                    screenshotPlaceholder.style.display = 'none';
                    
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
        
        async function startAutomation() {
            if (automationRunning) return;
            
            showLoading('Starting automation...');
            
            try {
                const response = await fetch('/automation/start', { method: 'POST' });
                const data = await response.json();
                
                if (data.success) {
                    automationRunning = true;
                    updateStatus();
                    addLog('Automation started - Pressing Ctrl+Enter every 5 minutes', 'success');
                    showNotification('Automation started!', 'success');
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
        
        async function stopAutomation() {
            if (!automationRunning) return;
            
            showLoading('Stopping automation...');
            
            try {
                const response = await fetch('/automation/stop', { method: 'POST' });
                const data = await response.json();
                
                if (data.success) {
                    automationRunning = false;
                    updateStatus();
                    addLog('Automation stopped', 'success');
                    showNotification('Automation stopped', 'info');
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
        
        async function refreshCookies() {
            showLoading('Refreshing cookies...');
            
            try {
                const response = await fetch('/cookies/refresh', { method: 'POST' });
                const data = await response.json();
                
                if (data.success) {
                    await fetchCookiesStatus();
                    addLog(`Refreshed ${data.cookies_count} cookies`, 'success');
                    showNotification('Cookies refreshed successfully', 'success');
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
        
        async function restoreGoogle() {
            showLoading('Restoring to Google.com...');
            
            try {
                const response = await fetch('/restore', { method: 'POST' });
                const data = await response.json();
                
                if (data.success) {
                    currentUrl = 'https://www.google.com';
                    colabUrlInput.value = '';
                    updateStatus();
                    addLog('Restored to Google.com', 'success');
                    showNotification('Restored to Google.com', 'success');
                    await takeScreenshot();
                } else {
                    throw new Error(data.error || 'Failed to restore');
                }
            } catch (error) {
                addLog(`Failed to restore: ${error.message}`, 'error');
                showNotification(`Error: ${error.message}`, 'error');
            } finally {
                hideLoading();
            }
        }
        
        // Event Listeners
        loadUrlBtn.addEventListener('click', loadUrl);
        
        getScreenshotBtn.addEventListener('click', takeScreenshot);
        
        startAutomationBtn.addEventListener('click', startAutomation);
        
        stopAutomationBtn.addEventListener('click', stopAutomation);
        
        refreshCookiesBtn.addEventListener('click', refreshCookies);
        
        restoreBtn.addEventListener('click', restoreGoogle);
        
        clearLogsBtn.addEventListener('click', () => {
            logBox.innerHTML = '<div class="log-entry"><span class="log-time">[System]</span><span class="log-info"> Logs cleared</span></div>';
            logs = [];
            addLog('Logs cleared', 'info');
        });
        
        colabUrlInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                loadUrl();
            }
        });
        
        // Auto-refresh cookies status every 30 seconds
        setInterval(fetchCookiesStatus, 30000);
        
        // Initial log
        addLog('Dashboard ready - Load a Colab URL to start', 'info');
    </script>
</body>
</html>
EOF

# Create FastAPI server
RUN cat > main.py << 'EOF'
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from playwright.async_api import async_playwright
import uuid
import os
import asyncio
import time
from datetime import datetime
import threading
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Colab Automation Dashboard")

# Setup templates
templates = Jinja2Templates(directory="templates")

# Create directories
os.makedirs("screenshots", exist_ok=True)
os.makedirs("static", exist_ok=True)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Global state
browser = None
page = None
context = None
playwright_instance = None
automation_running = False
automation_task = None
current_url = "https://www.google.com"
cookies = []

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
    """Initialize browser with cookies."""
    global browser, page, context, playwright_instance, cookies
    
    try:
        logger.info("🚀 Initializing browser...")
        
        # Download cookies first
        await download_cookies()
        
        # Start Playwright
        playwright_instance = await async_playwright().start()
        browser = await playwright_instance.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
        
        # Create context with user agent
        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
        
        # Add cookies if available
        if cookies:
            await context.add_cookies(cookies)
            logger.info(f"✅ Added {len(cookies)} cookies to browser")
        
        # Create page
        page = await context.new_page()
        
        # Navigate to Google
        logger.info("🌐 Navigating to google.com...")
        await page.goto("https://www.google.com", wait_until="domcontentloaded", timeout=30000)
        
        # Take initial screenshot
        await take_screenshot("initial")
        
        logger.info("✅ Browser initialized successfully")
        return True
        
    except Exception as e:
        logger.error(f"❌ Browser initialization error: {e}")
        return False

async def take_screenshot(label: str = ""):
    """Take screenshot of current page."""
    global page
    
    if not page:
        return None
    
    try:
        filename = f"screenshot_{label}_{uuid.uuid4().hex[:8]}_{int(time.time())}.png"
        filepath = os.path.join("screenshots", filename)
        
        await page.screenshot(path=filepath, full_page=True)
        logger.info(f"📸 Screenshot saved: {filename}")
        
        # Clean old screenshots (keep last 20)
        screenshots = sorted(os.listdir("screenshots"), key=lambda x: os.path.getctime(os.path.join("screenshots", x)))
        for old_file in screenshots[:-20]:
            try:
                os.remove(os.path.join("screenshots", old_file))
            except:
                pass
        
        return filename
        
    except Exception as e:
        logger.error(f"❌ Screenshot error: {e}")
        return None

async def automation_loop():
    """Background automation loop - presses Ctrl+Enter every 5 minutes."""
    global page, automation_running, current_url
    
    logger.info("🤖 Starting automation loop...")
    
    iteration = 0
    while automation_running:
        try:
            iteration += 1
            logger.info(f"⏱️ Iteration {iteration}: Pressing Ctrl+Enter...")
            
            # Focus on page and press Ctrl+Enter
            await page.focus('body')
            await page.keyboard.down('Control')
            await page.keyboard.press('Enter')
            await page.keyboard.up('Control')
            
            logger.info(f"✅ Ctrl+Enter pressed (iteration {iteration})")
            
            # Wait 5 minutes
            for _ in range(300):  # 300 seconds = 5 minutes
                if not automation_running:
                    break
                await asyncio.sleep(1)
                
        except Exception as e:
            logger.error(f"❌ Automation error: {e}")
            await asyncio.sleep(10)
    
    logger.info("🛑 Automation loop stopped")

@app.on_event("startup")
async def startup_event():
    """Initialize browser on startup."""
    logger.info("=" * 60)
    logger.info("🤖 Colab Automation Dashboard Starting")
    logger.info("=" * 60)
    
    success = await init_browser()
    if not success:
        logger.error("❌ Failed to initialize browser - some features may not work")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    global browser, playwright_instance, automation_task
    
    # Stop automation
    global automation_running
    automation_running = False
    
    if automation_task:
        automation_task.cancel()
    
    # Close browser
    if browser:
        await browser.close()
        logger.info("✅ Browser closed")
    
    if playwright_instance:
        await playwright_instance.stop()
    
    logger.info("👋 Server shutdown complete")

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Serve the dashboard."""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/status")
async def get_status():
    """Get current status."""
    return JSONResponse({
        "browser_ready": page is not None,
        "automation_running": automation_running,
        "current_url": current_url,
        "cookies_count": len(cookies),
        "last_update": datetime.now().isoformat()
    })

@app.post("/load")
async def load_url(request: Request):
    """Load a new URL in the browser."""
    global page, current_url
    
    try:
        data = await request.json()
        url = data.get("url", "").strip()
        
        if not url:
            return JSONResponse({"success": False, "error": "No URL provided"})
        
        if not page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        logger.info(f"🌐 Loading URL: {url}")
        
        # Ensure URL has protocol
        if not url.startswith(("http://", "https://")):
            url = "https://" + url
        
        # Navigate to URL
        await page.goto(url, wait_until="domcontentloaded", timeout=30000)
        
        current_url = url
        logger.info(f"✅ Loaded: {url}")
        
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
    """Take and return screenshot."""
    try:
        if not page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        filename = await take_screenshot("api")
        if filename:
            return JSONResponse({
                "success": True,
                "filename": filename,
                "url": f"/screenshots/{filename}"
            })
        else:
            return JSONResponse({"success": False, "error": "Failed to take screenshot"})
            
    except Exception as e:
        logger.error(f"❌ Screenshot API error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/screenshots/{filename}")
async def serve_screenshot(filename: str):
    """Serve screenshot file."""
    filepath = os.path.join("screenshots", filename)
    if os.path.exists(filepath):
        return FileResponse(filepath, media_type="image/png")
    raise HTTPException(status_code=404, detail="Screenshot not found")

@app.post("/automation/start")
async def start_automation():
    """Start the automation loop."""
    global automation_running, automation_task, page
    
    try:
        if automation_running:
            return JSONResponse({"success": False, "error": "Automation already running"})
        
        if not page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        automation_running = True
        automation_task = asyncio.create_task(automation_loop())
        
        logger.info("▶️ Automation started")
        
        return JSONResponse({
            "success": True,
            "message": "Automation started - pressing Ctrl+Enter every 5 minutes"
        })
        
    except Exception as e:
        logger.error(f"❌ Start automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/stop")
async def stop_automation():
    """Stop the automation loop."""
    global automation_running, automation_task
    
    try:
        if not automation_running:
            return JSONResponse({"success": False, "error": "Automation not running"})
        
        automation_running = False
        
        if automation_task:
            automation_task.cancel()
            automation_task = None
        
        logger.info("⏹️ Automation stopped")
        
        return JSONResponse({
            "success": True,
            "message": "Automation stopped"
        })
        
    except Exception as e:
        logger.error(f"❌ Stop automation error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/cookies/refresh")
async def refresh_cookies():
    """Refresh cookies from download URL."""
    try:
        success = await download_cookies()
        
        if success and cookies and context:
            # Clear old cookies and add new ones
            await context.clear_cookies()
            await context.add_cookies(cookies)
            
            # Reload current page
            if page:
                await page.reload()
            
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

@app.post("/restore")
async def restore_google():
    """Restore browser to Google.com."""
    global page, current_url
    
    try:
        if not page:
            return JSONResponse({"success": False, "error": "Browser not initialized"})
        
        logger.info("🔄 Restoring to Google.com...")
        
        await page.goto("https://www.google.com", wait_until="domcontentloaded", timeout=30000)
        current_url = "https://www.google.com"
        
        logger.info("✅ Restored to Google.com")
        
        return JSONResponse({
            "success": True,
            "message": "Restored to Google.com"
        })
        
    except Exception as e:
        logger.error(f"❌ Restore error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/logs")
async def get_logs():
    """Get recent logs (simplified)."""
    return JSONResponse({
        "logs": [
            {"time": datetime.now().isoformat(), "message": "System is running", "type": "info"}
        ]
    })

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return JSONResponse({
        "status": "healthy",
        "browser_ready": page is not None,
        "automation_running": automation_running,
        "timestamp": datetime.now().isoformat()
    })

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
EOF

# Remove cron related lines (lines 1194-1198)

# Expose port
EXPOSE 8000

# Run the web server
CMD ["python", "main.py"]
