FROM python:3.11-slim

# Install system dependencies for Playwright
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libexpat1 \
    libgbm1 \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright and Chrome browser
RUN pip install playwright==1.40.0
RUN playwright install chromium --with-deps

# Create main.py
COPY main.py .

# Create requirements.txt if not exists
RUN echo "playwright==1.40.0\nfastapi==0.104.1\nuvicorn==0.24.0\nrequests==2.31.0" > requirements.txt

# Create main.py if not exists
RUN cat > main.py << 'EOF'
from fastapi import FastAPI
from playwright.sync_api import sync_playwright
import uvicorn
import os
import uuid

app = FastAPI()

@app.get("/")
def home():
    return {"message": "✅ Playwright Automation Server Running", "endpoints": ["/screenshot", "/screenshot/{url}"]}

@app.get("/screenshot")
def take_screenshot(url: str = "https://google.com"):
    try:
        with sync_playwright() as p:
            # Launch browser
            browser = p.chromium.launch(headless=True)
            page = browser.new_page(viewport={'width': 1920, 'height': 1080})
            
            # Navigate and wait
            page.goto(url, wait_until="networkidle")
            
            # Generate filename
            filename = f"screenshot_{uuid.uuid4().hex[:8]}.png"
            
            # Take screenshot
            page.screenshot(path=filename, full_page=False)
            browser.close()
            
            # Get file size
            file_size = os.path.getsize(filename)
            
            return {
                "success": True,
                "filename": filename,
                "url": url,
                "size_bytes": file_size,
                "download_url": f"/download/{filename}",
                "message": "Screenshot captured successfully"
            }
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.get("/screenshot/{url:path}")
def take_screenshot_custom(url: str):
    # Ensure URL has protocol
    if not url.startswith("http"):
        url = "https://" + url
    return take_screenshot(url)

@app.get("/download/{filename}")
def download_file(filename: str):
    from fastapi.responses import FileResponse
    if os.path.exists(filename):
        return FileResponse(filename, media_type="image/png")
    return {"error": "File not found"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "playwright-automation"}

# Test on startup
@app.on_event("startup")
def startup_event():
    print("🚀 Starting Playwright automation server...")
    print("✅ Server is ready at http://0.0.0.0:8000")
    print("📸 Try: /screenshot or /screenshot/https://github.com")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 8000)))
EOF

# Expose port
EXPOSE 8000

# Run the application
CMD ["python", "main.py"]
