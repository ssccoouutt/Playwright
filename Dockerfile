FROM python:3.11-slim

# Minimal dependencies for Playwright
RUN apt-get update && apt-get install -y \
    libnss3 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libcups2 \
    libxkbcommon0 \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install only essential packages
RUN pip install playwright==1.40.0 fastapi==0.104.1 uvicorn==0.24.0

# Install Chromium (minimal)
RUN playwright install chromium --with-deps chromium

# Create simple HTML
RUN mkdir -p templates && cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Colab Automation</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; max-width: 800px; }
        .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); margin-bottom: 20px; }
        input { width: 100%; padding: 10px; margin: 10px 0; box-sizing: border-box; }
        button { padding: 10px 20px; margin: 5px; border: none; border-radius: 5px; cursor: pointer; }
        .btn-go { background: #007bff; color: white; }
        .btn-start { background: #28a745; color: white; }
        .btn-stop { background: #dc3545; color: white; }
        .status { padding: 10px; background: #f8f9fa; border-radius: 5px; margin: 10px 0; font-family: monospace; }
        .screenshot { max-width: 100%; border: 1px solid #ddd; border-radius: 5px; margin-top: 10px; }
        .log { background: #1e1e1e; color: #00ff00; padding: 10px; border-radius: 5px; height: 150px; overflow-y: auto; font-family: monospace; font-size: 12px; }
    </style>
</head>
<body>
    <h1>🤖 Colab Automation</h1>
    
    <div class="card">
        <h3>🌐 Browser Control</h3>
        <input type="url" id="urlInput" placeholder="https://colab.research.google.com/..." value="https://colab.research.google.com/">
        <button class="btn-go" onclick="loadUrl()">Load URL</button>
        <button onclick="takeScreenshot()">📸 Screenshot</button>
    </div>
    
    <div class="card">
        <h3>⚡ Automation</h3>
        <div class="status">
            Status: <span id="statusText">Checking...</span><br>
            URL: <span id="currentUrl">-</span>
        </div>
        <button class="btn-start" onclick="startAutomation()" id="startBtn">▶ Start (Ctrl+Enter every 5min)</button>
        <button class="btn-stop" onclick="stopAutomation()" id="stopBtn" disabled>⏹ Stop</button>
        <button onclick="refreshCookies()">🔄 Refresh Cookies</button>
        <button onclick="restoreGoogle()">🏠 Reset to Google</button>
    </div>
    
    <div class="card">
        <h3>📸 Screenshot</h3>
        <img id="screenshotImg" class="screenshot" style="display: none;">
        <div id="screenshotPlaceholder">No screenshot yet</div>
    </div>
    
    <div class="card">
        <h3>📋 Activity Log</h3>
        <div id="logBox" class="log">[System] Loading...</div>
    </div>
    
    <script>
        let automationRunning = false;
        
        // Initialize
        updateStatus();
        setInterval(updateStatus, 5000); // Update every 5 seconds
        
        function addLog(message) {
            const logBox = document.getElementById('logBox');
            const time = new Date().toLocaleTimeString();
            logBox.innerHTML += `<div>[${time}] ${message}</div>`;
            logBox.scrollTop = logBox.scrollHeight;
        }
        
        async function updateStatus() {
            try {
                const response = await fetch('/status');
                if (!response.ok) throw new Error('Status failed');
                
                const data = await response.json();
                document.getElementById('currentUrl').textContent = data.current_url || '-';
                document.getElementById('statusText').textContent = data.automation_running ? 'Running' : 'Stopped';
                document.getElementById('statusText').style.color = data.automation_running ? 'green' : 'red';
                
                automationRunning = data.automation_running;
                document.getElementById('startBtn').disabled = automationRunning;
                document.getElementById('stopBtn').disabled = !automationRunning;
            } catch (error) {
                console.error('Status update failed:', error);
            }
        }
        
        async function loadUrl() {
            const url = document.getElementById('urlInput').value.trim();
            if (!url) {
                addLog('❌ Please enter a URL');
                return;
            }
            
            addLog(`Loading: ${url}`);
            
            try {
                const response = await fetch('/load', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({url: url})
                });
                
                const data = await response.json();
                if (data.success) {
                    addLog('✅ URL loaded');
                    takeScreenshot();
                } else {
                    addLog(`❌ Error: ${data.error}`);
                }
            } catch (error) {
                addLog(`❌ Failed to load: ${error.message}`);
            }
        }
        
        async function takeScreenshot() {
            addLog('Taking screenshot...');
            
            try {
                const response = await fetch('/screenshot');
                const data = await response.json();
                
                if (data.success) {
                    const img = document.getElementById('screenshotImg');
                    img.src = `/screenshots/${data.filename}?t=${Date.now()}`;
                    img.style.display = 'block';
                    document.getElementById('screenshotPlaceholder').style.display = 'none';
                    addLog('✅ Screenshot saved');
                }
            } catch (error) {
                addLog(`❌ Screenshot error: ${error.message}`);
            }
        }
        
        async function startAutomation() {
            if (automationRunning) return;
            
            addLog('Starting automation...');
            
            try {
                const response = await fetch('/automation/start', {method: 'POST'});
                const data = await response.json();
                
                if (data.success) {
                    addLog('✅ Automation started - pressing Ctrl+Enter every 5 minutes');
                    updateStatus();
                }
            } catch (error) {
                addLog(`❌ Start error: ${error.message}`);
            }
        }
        
        async function stopAutomation() {
            if (!automationRunning) return;
            
            addLog('Stopping automation...');
            
            try {
                const response = await fetch('/automation/stop', {method: 'POST'});
                const data = await response.json();
                
                if (data.success) {
                    addLog('✅ Automation stopped');
                    updateStatus();
                }
            } catch (error) {
                addLog(`❌ Stop error: ${error.message}`);
            }
        }
        
        async function refreshCookies() {
            addLog('Refreshing cookies...');
            
            try {
                const response = await fetch('/cookies/refresh', {method: 'POST'});
                const data = await response.json();
                
                if (data.success) {
                    addLog(`✅ Refreshed ${data.cookies_count} cookies`);
                }
            } catch (error) {
                addLog(`❌ Cookie refresh error: ${error.message}`);
            }
        }
        
        async function restoreGoogle() {
            addLog('Resetting to Google...');
            
            try {
                const response = await fetch('/restore', {method: 'POST'});
                const data = await response.json();
                
                if (data.success) {
                    document.getElementById('urlInput').value = '';
                    addLog('✅ Reset to Google.com');
                    takeScreenshot();
                }
            } catch (error) {
                addLog(`❌ Reset error: ${error.message}`);
            }
        }
        
        // Initial log
        addLog('[System] Dashboard ready');
    </script>
</body>
</html>
EOF

# Create Python server with auto-restart and minimal logging
RUN cat > main.py << 'EOF'
import asyncio
import os
import time
import uuid
import logging
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from playwright.async_api import async_playwright

# Configure minimal logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger(__name__)

# Global state with auto-restart capability
class BrowserManager:
    def __init__(self):
        self.playwright = None
        self.browser = None
        self.page = None
        self.automation_running = False
        self.automation_task = None
        self.current_url = "https://www.google.com"
        self.cookies = []
        self.restart_count = 0
        self.last_restart = None
        
    async def start(self):
        """Start or restart browser"""
        try:
            await self.cleanup()
            logger.info("🚀 Starting browser...")
            
            self.playwright = await async_playwright().start()
            
            # Minimal browser launch for 512MB RAM
            self.browser = await self.playwright.chromium.launch(
                headless=True,
                args=[
                    '--no-sandbox',
                    '--disable-dev-shm-usage',
                    '--disable-gpu',
                    '--disable-software-rasterizer',
                    '--disable-background-timer-throttling',
                    '--disable-backgrounding-occluded-windows',
                    '--disable-renderer-backgrounding',
                    '--memory-pressure-off',
                    '--disable-features=VizDisplayCompositor'
                ]
            )
            
            # Single context for minimal memory
            context = await self.browser.new_context(
                viewport={'width': 1280, 'height': 720},  # Smaller viewport
                user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            )
            
            # Load cookies if available
            await self.load_cookies(context)
            
            self.page = await context.new_page()
            
            # Navigate to Google
            logger.info("🌐 Loading Google.com...")
            await self.page.goto("https://www.google.com", wait_until="domcontentloaded", timeout=30000)
            
            self.restart_count += 1
            self.last_restart = datetime.now()
            logger.info(f"✅ Browser ready (Restart #{self.restart_count})")
            return True
            
        except Exception as e:
            logger.error(f"❌ Browser start failed: {e}")
            await self.cleanup()
            return False
    
    async def load_cookies(self, context):
        """Load cookies from URL"""
        try:
            import requests
            COOKIES_URL = "https://drive.usercontent.google.com/download?id=1NFy-Y6hnDlIDEyFnWSvLOxm4_eyIRsvm&export=download"
            
            logger.info("📥 Downloading cookies...")
            response = requests.get(COOKIES_URL, timeout=10)
            
            if response.status_code == 200:
                # Parse Netscape format cookies
                self.cookies = []
                for line in response.text.strip().split('\n'):
                    line = line.strip()
                    if not line or line.startswith('#'):
                        continue
                    parts = line.split('\t')
                    if len(parts) >= 7:
                        self.cookies.append({
                            "name": parts[5],
                            "value": parts[6],
                            "domain": parts[0],
                            "path": parts[2],
                            "secure": parts[3].lower() == "true",
                        })
                
                if self.cookies:
                    await context.add_cookies(self.cookies)
                    logger.info(f"✅ Loaded {len(self.cookies)} cookies")
                else:
                    logger.info("⚠️  No cookies loaded")
            else:
                logger.info("⚠️  Could not download cookies")
                
        except Exception as e:
            logger.info(f"⚠️  Cookie load failed: {e}")
    
    async def cleanup(self):
        """Cleanup resources"""
        if self.automation_task:
            self.automation_running = False
            try:
                self.automation_task.cancel()
            except:
                pass
        
        if self.page:
            try:
                await self.page.close()
            except:
                pass
        
        if self.browser:
            try:
                await self.browser.close()
            except:
                pass
        
        if self.playwright:
            try:
                await self.playwright.stop()
            except:
                pass
    
    async def restart_if_needed(self):
        """Check if browser needs restart and restart it"""
        try:
            # Try to check if page is alive
            if self.page:
                await self.page.title()  # Simple check
                return True
        except:
            logger.warning("⚠️  Browser appears dead, restarting...")
            return await self.start()
        return True
    
    async def automation_loop(self):
        """Background automation task"""
        logger.info("🤖 Automation started")
        iteration = 0
        
        while self.automation_running:
            try:
                # Check browser health before each iteration
                if not await self.restart_if_needed():
                    logger.error("❌ Browser restart failed, stopping automation")
                    self.automation_running = False
                    break
                
                iteration += 1
                logger.info(f"⏱️  Pressing Ctrl+Enter (#{iteration})...")
                
                # Press Ctrl+Enter
                await self.page.keyboard.down('Control')
                await self.page.press('body', 'Enter')
                await self.page.keyboard.up('Control')
                
                logger.info(f"✅ Ctrl+Enter pressed (#{iteration})")
                
                # Wait 5 minutes, checking every second if still running
                for _ in range(300):
                    if not self.automation_running:
                        break
                    await asyncio.sleep(1)
                    
            except Exception as e:
                logger.error(f"❌ Automation error: {e}")
                await asyncio.sleep(10)  # Wait before retry
        
        logger.info("🛑 Automation stopped")

# Create browser manager
browser_manager = BrowserManager()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown"""
    # Startup
    logger.info("=" * 40)
    logger.info("🤖 Colab Automation Starting")
    logger.info("=" * 40)
    
    # Try to start browser
    success = False
    for attempt in range(3):  # Try 3 times
        logger.info(f"Attempt {attempt + 1}/3 to start browser...")
        success = await browser_manager.start()
        if success:
            break
        await asyncio.sleep(5)
    
    if not success:
        logger.error("❌ Failed to start browser after 3 attempts")
    
    yield  # App runs here
    
    # Shutdown
    logger.info("🛑 Shutting down...")
    await browser_manager.cleanup()
    logger.info("👋 Goodbye")

# Create app
app = FastAPI(lifespan=lifespan, docs_url=None, redoc_url=None)
templates = Jinja2Templates(directory="templates")

# Create screenshots directory
os.makedirs("screenshots", exist_ok=True)

@app.get("/")
async def home(request: Request):
    """Serve main page"""
    return templates.TemplateResponse("index.html", {"request": request})

@app.get("/status")
async def get_status():
    """Get current status"""
    return JSONResponse({
        "current_url": browser_manager.current_url,
        "automation_running": browser_manager.automation_running,
        "cookies_count": len(browser_manager.cookies),
        "restart_count": browser_manager.restart_count,
        "last_restart": browser_manager.last_restart.isoformat() if browser_manager.last_restart else None
    })

@app.post("/load")
async def load_url(request: Request):
    """Load a URL"""
    try:
        data = await request.json()
        url = data.get("url", "").strip()
        
        if not url:
            return JSONResponse({"success": False, "error": "No URL provided"})
        
        # Ensure browser is alive
        if not await browser_manager.restart_if_needed():
            return JSONResponse({"success": False, "error": "Browser not available"})
        
        # Ensure URL has protocol
        if not url.startswith(("http://", "https://")):
            url = "https://" + url
        
        logger.info(f"🌐 Loading: {url}")
        
        try:
            await browser_manager.page.goto(url, wait_until="domcontentloaded", timeout=60000)
            browser_manager.current_url = url
            logger.info(f"✅ Loaded: {url}")
            return JSONResponse({"success": True, "url": url})
        except Exception as nav_error:
            logger.warning(f"⚠️  Navigation issue: {nav_error}")
            # Still return success if we got somewhere
            browser_manager.current_url = url
            return JSONResponse({"success": True, "url": url, "warning": str(nav_error)})
            
    except Exception as e:
        logger.error(f"❌ Load error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/screenshot")
async def get_screenshot():
    """Take screenshot"""
    try:
        if not await browser_manager.restart_if_needed():
            return JSONResponse({"success": False, "error": "Browser not available"})
        
        filename = f"screenshot_{uuid.uuid4().hex[:8]}.png"
        filepath = os.path.join("screenshots", filename)
        
        await browser_manager.page.screenshot(path=filepath, full_page=False)  # Not full page to save memory
        
        # Clean old screenshots
        try:
            files = os.listdir("screenshots")
            if len(files) > 10:
                for old_file in sorted(files)[:-10]:
                    os.remove(os.path.join("screenshots", old_file))
        except:
            pass
        
        logger.info(f"📸 Saved: {filename}")
        return JSONResponse({"success": True, "filename": filename})
        
    except Exception as e:
        logger.error(f"❌ Screenshot error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/screenshots/{filename}")
async def serve_screenshot(filename: str):
    """Serve screenshot"""
    filepath = os.path.join("screenshots", filename)
    if os.path.exists(filepath):
        return FileResponse(filepath, media_type="image/png")
    raise HTTPException(status_code=404, detail="Screenshot not found")

@app.post("/automation/start")
async def start_automation():
    """Start automation"""
    try:
        if browser_manager.automation_running:
            return JSONResponse({"success": False, "error": "Already running"})
        
        if not await browser_manager.restart_if_needed():
            return JSONResponse({"success": False, "error": "Browser not available"})
        
        browser_manager.automation_running = True
        browser_manager.automation_task = asyncio.create_task(browser_manager.automation_loop())
        
        logger.info("▶️  Automation started")
        return JSONResponse({"success": True, "message": "Automation started"})
        
    except Exception as e:
        logger.error(f"❌ Start error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/automation/stop")
async def stop_automation():
    """Stop automation"""
    browser_manager.automation_running = False
    logger.info("⏹️  Automation stopped")
    return JSONResponse({"success": True, "message": "Automation stopped"})

@app.post("/cookies/refresh")
async def refresh_cookies():
    """Refresh cookies"""
    try:
        if not await browser_manager.restart_if_needed():
            return JSONResponse({"success": False, "error": "Browser not available"})
        
        # Get current context and reload cookies
        context = browser_manager.page.context
        await context.clear_cookies()
        await browser_manager.load_cookies(context)
        
        # Reload current page
        await browser_manager.page.reload()
        
        logger.info("🔄 Cookies refreshed")
        return JSONResponse({
            "success": True,
            "cookies_count": len(browser_manager.cookies),
            "message": "Cookies refreshed"
        })
        
    except Exception as e:
        logger.error(f"❌ Cookie refresh error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.post("/restore")
async def restore_google():
    """Go back to Google"""
    try:
        if not await browser_manager.restart_if_needed():
            return JSONResponse({"success": False, "error": "Browser not available"})
        
        await browser_manager.page.goto("https://www.google.com", wait_until="domcontentloaded")
        browser_manager.current_url = "https://www.google.com"
        
        logger.info("🏠 Restored to Google.com")
        return JSONResponse({"success": True, "message": "Restored to Google.com"})
        
    except Exception as e:
        logger.error(f"❌ Restore error: {e}")
        return JSONResponse({"success": False, "error": str(e)})

@app.get("/health")
async def health_check():
    """Health endpoint for Koyeb"""
    try:
        # Simple health check
        if browser_manager.page:
            return JSONResponse({"status": "healthy", "browser": "alive"})
        else:
            return JSONResponse({"status": "starting", "browser": "initializing"})
    except:
        return JSONResponse({"status": "unhealthy", "browser": "dead"}, status_code=500)

if __name__ == "__main__":
    import uvicorn
    # Run with minimal workers for 512MB RAM
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 8000)),
        workers=1,  # Single worker to save RAM
        log_level="warning"  # Reduce log noise
    )
EOF

# Create directories
RUN mkdir -p /app/screenshots

# Create startup script to handle crashes
RUN cat > start.sh << 'EOF'
#!/bin/bash
echo "========================================"
echo "🤖 Starting Colab Automation"
echo "========================================"
echo "Memory: $(free -m | awk 'NR==2{printf "%.1f/%.1f MB", $3/1024, $2/1024}')"
echo "========================================"

# Start the server
python main.py
EOF

RUN chmod +x start.sh

EXPOSE 8000

CMD ["./start.sh"]
