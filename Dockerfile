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
RUN pip install playwright==1.40.0 fastapi==0.104.1 uvicorn==0.24.0 python-multipart jinja2

# Install Chromium browser
RUN playwright install chromium

# Create HTML template for the web interface
RUN mkdir -p templates && cat > templates/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>📸 Screenshot Tool</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .container {
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            text-align: center;
        }
        .input-group {
            margin: 20px 0;
        }
        input[type="url"] {
            width: 100%;
            padding: 12px;
            font-size: 16px;
            border: 2px solid #ddd;
            border-radius: 5px;
            box-sizing: border-box;
        }
        button {
            background: #007bff;
            color: white;
            border: none;
            padding: 12px 24px;
            font-size: 16px;
            border-radius: 5px;
            cursor: pointer;
            width: 100%;
            margin-top: 10px;
        }
        button:hover {
            background: #0056b3;
        }
        .result {
            margin-top: 20px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 5px;
            display: none;
        }
        .result img {
            max-width: 100%;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .download-link {
            display: block;
            margin-top: 10px;
            color: #007bff;
            text-decoration: none;
        }
        .download-link:hover {
            text-decoration: underline;
        }
        .loading {
            text-align: center;
            color: #666;
            display: none;
        }
        .error {
            color: #dc3545;
            margin-top: 10px;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📸 Browser Screenshot Tool</h1>
        <p>Enter any URL below to take a screenshot:</p>
        
        <form id="screenshotForm">
            <div class="input-group">
                <input type="url" 
                       id="urlInput" 
                       placeholder="https://example.com" 
                       value="https://google.com"
                       required>
            </div>
            <button type="submit">Take Screenshot</button>
        </form>
        
        <div class="loading" id="loading">
            <p>⏳ Taking screenshot, please wait 3-5 seconds...</p>
        </div>
        
        <div class="error" id="error">
            <p id="errorText"></p>
        </div>
        
        <div class="result" id="result">
            <h3>✅ Screenshot Ready!</h3>
            <img id="screenshotImage" src="" alt="Screenshot">
            <a id="downloadLink" class="download-link" href="" download>
                ⬇️ Download Full Size Image
            </a>
            <p><small>Image will be automatically deleted after 5 minutes</small></p>
        </div>
    </div>
    
    <script>
        document.getElementById('screenshotForm').addEventListener('submit', async function(e) {
            e.preventDefault();
            
            const url = document.getElementById('urlInput').value.trim();
            const loading = document.getElementById('loading');
            const result = document.getElementById('result');
            const error = document.getElementById('error');
            
            // Reset UI
            loading.style.display = 'block';
            result.style.display = 'none';
            error.style.display = 'none';
            
            try {
                // Call the API
                const response = await fetch('/screenshot', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({ url: url })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    // Show the screenshot
                    document.getElementById('screenshotImage').src = `/screenshots/${data.filename}`;
                    document.getElementById('downloadLink').href = `/download/${data.filename}`;
                    result.style.display = 'block';
                } else {
                    document.getElementById('errorText').textContent = 'Error: ' + data.error;
                    error.style.display = 'block';
                }
            } catch (error) {
                document.getElementById('errorText').textContent = 'Failed to take screenshot: ' + error.message;
                error.style.display = 'block';
            } finally {
                loading.style.display = 'none';
            }
        });
        
        // Auto-focus the input
        document.getElementById('urlInput').focus();
    </script>
</body>
</html>
EOF

# Create the FastAPI web server with ASYNC Playwright
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

app = FastAPI(title="Screenshot Tool")

# Setup templates
templates = Jinja2Templates(directory="templates")

# Create directories
os.makedirs("screenshots", exist_ok=True)
os.makedirs("static", exist_ok=True)

# Mount static files
app.mount("/static", StaticFiles(directory="static"), name="static")

# Store browser instance for reuse
_browser = None
_playwright = None

async def get_browser():
    """Get or create browser instance (singleton)"""
    global _browser, _playwright
    if _browser is None:
        _playwright = await async_playwright().start()
        _browser = await _playwright.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
    return _browser

async def cleanup_browser():
    """Cleanup browser on shutdown"""
    global _browser, _playwright
    if _browser:
        await _browser.close()
    if _playwright:
        await _playwright.stop()

# Cleanup old screenshots every hour
def cleanup_old_files():
    while True:
        try:
            now = time.time()
            for filename in os.listdir("screenshots"):
                filepath = os.path.join("screenshots", filename)
                # Delete files older than 5 minutes
                if os.path.getmtime(filepath) < now - 300:
                    os.remove(filepath)
                    print(f"Cleaned up: {filename}")
        except:
            pass
        time.sleep(3600)  # Run every hour

# Start cleanup thread
cleanup_thread = threading.Thread(target=cleanup_old_files, daemon=True)
cleanup_thread.start()

@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Home page with input form"""
    return templates.TemplateResponse("index.html", {"request": request})

@app.post("/screenshot")
async def take_screenshot(request: Request):
    """API endpoint to take screenshot - ASYNC VERSION"""
    try:
        data = await request.json()
        url = data.get("url", "https://google.com")
        
        # Ensure URL has protocol
        if not url.startswith(("http://", "https://")):
            url = "https://" + url
        
        print(f"Taking screenshot of: {url}")
        
        # Get browser instance
        browser = await get_browser()
        
        # Create new page context
        context = await browser.new_context(viewport={'width': 1920, 'height': 1080})
        page = await context.new_page()
        
        try:
            await page.goto(url, wait_until="networkidle", timeout=30000)
        except Exception as e:
            print(f"Navigation warning: {e}")
            # Continue anyway
        
        # Generate unique filename
        filename = f"screenshot_{uuid.uuid4().hex[:8]}_{int(time.time())}.png"
        filepath = os.path.join("screenshots", filename)
        
        # Take screenshot
        await page.screenshot(path=filepath, full_page=True)
        
        # Cleanup
        await context.close()
        
        # Get file size
        file_size = os.path.getsize(filepath)
        
        return JSONResponse({
            "success": True,
            "filename": filename,
            "url": url,
            "size": file_size,
            "timestamp": datetime.now().isoformat(),
            "view_url": f"/screenshots/{filename}",
            "download_url": f"/download/{filename}"
        })
        
    except Exception as e:
        return JSONResponse({
            "success": False,
            "error": str(e)
        }, status_code=500)

@app.get("/screenshots/{filename}")
async def get_screenshot(filename: str):
    """Serve screenshot image"""
    filepath = os.path.join("screenshots", filename)
    if os.path.exists(filepath):
        return FileResponse(filepath, media_type="image/png")
    raise HTTPException(status_code=404, detail="Screenshot not found")

@app.get("/download/{filename}")
async def download_screenshot(filename: str):
    """Download screenshot"""
    filepath = os.path.join("screenshots", filename)
    if os.path.exists(filepath):
        return FileResponse(
            filepath,
            media_type="image/png",
            filename=filename
        )
    raise HTTPException(status_code=404, detail="File not found")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "screenshot-tool"}

@app.get("/api/screenshot")
async def quick_screenshot(url: str = "https://google.com"):
    """Quick API endpoint (GET request)"""
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    
    browser = await get_browser()
    context = await browser.new_context()
    page = await context.new_page()
    
    try:
        await page.goto(url, wait_until="networkidle", timeout=15000)
    except:
        pass
    
    filename = f"quick_{uuid.uuid4().hex[:8]}.png"
    filepath = os.path.join("screenshots", filename)
    await page.screenshot(path=filepath, full_page=True)
    
    await context.close()
    
    return {
        "success": True,
        "filename": filename,
        "download": f"/download/{filename}"
    }

@app.on_event("startup")
async def startup_event():
    """Initialize browser on startup"""
    print("🚀 Starting Screenshot Web Server...")
    print("📸 Visit http://localhost:8000")
    print("⚡ API: POST /screenshot with JSON: {\"url\": \"https://example.com\"}")
    print("⚡ Quick API: GET /api/screenshot?url=https://example.com")
    
    # Warm up the browser
    try:
        await get_browser()
        print("✅ Browser initialized successfully")
    except Exception as e:
        print(f"⚠️ Browser initialization warning: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup browser on shutdown"""
    await cleanup_browser()
    print("👋 Browser closed")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
EOF

# Expose port
EXPOSE 8000

# Run the web server
CMD ["python", "main.py"]
