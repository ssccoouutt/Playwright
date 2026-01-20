FROM python:3.11-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libx11-6 libxcb1 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libgbm1 libasound2 \
    libcups2 libxkbcommon0 \
    fonts-liberation fonts-unifont \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Playwright + requests for uploading
RUN pip install playwright==1.40.0 requests

# Install Chromium
RUN playwright install chromium

# Create script that saves AND uploads screenshots
RUN cat > automation.py << 'EOF'
from playwright.sync_api import sync_playwright
import os
import sys
import time
from datetime import datetime
import requests
import base64

def upload_to_fileio(filename):
    """Upload file to file.io (free file hosting)"""
    try:
        with open(filename, 'rb') as f:
            response = requests.post(
                'https://file.io',
                files={'file': f},
                params={'expires': '1d'}  # File expires in 1 day
            )
        
        if response.status_code == 200:
            data = response.json()
            return data.get('link')
    except:
        return None

def save_and_share():
    print("=" * 60)
    print("🚀 PLAYWRIGHT AUTOMATION WITH FILE UPLOAD")
    print("=" * 60)
    
    files_links = {}
    
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(
                headless=True,
                args=['--no-sandbox', '--disable-dev-shm-usage']
            )
            
            page = browser.new_page(viewport={'width': 1920, 'height': 1080})
            
            # 1. Google screenshot
            print("📸 Taking Google screenshot...")
            page.goto("https://google.com", wait_until="networkidle", timeout=30000)
            google_file = f"google_{int(time.time())}.png"
            page.screenshot(path=google_file, full_page=True)
            print(f"✅ Saved: {google_file}")
            
            # 2. GitHub screenshot  
            print("📸 Taking GitHub screenshot...")
            page.goto("https://github.com")
            github_file = f"github_{int(time.time())}.png"
            page.screenshot(path=github_file)
            print(f"✅ Saved: {github_file}")
            
            browser.close()
            
            # Upload files
            print("\n📤 Uploading files...")
            for filename in [google_file, github_file]:
                if os.path.exists(filename):
                    print(f"  Uploading {filename}...")
                    link = upload_to_fileio(filename)
                    if link:
                        files_links[filename] = link
                        print(f"  ✅ Uploaded: {link}")
                    else:
                        print(f"  ❌ Upload failed for {filename}")
            
            # Show file sizes
            print("\n📁 Local files:")
            for file in os.listdir('.'):
                if file.endswith('.png'):
                    size = os.path.getsize(file)
                    print(f"  📸 {file} ({size:,} bytes)")
                    
    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
    
    # Print download links
    print("\n" + "=" * 60)
    print("🔗 DOWNLOAD LINKS (valid for 24 hours):")
    print("=" * 60)
    for filename, link in files_links.items():
        print(f"{filename}: {link}")
    
    print("\n💡 Tip: If uploads fail, add your own cloud storage")
    print("=" * 60)

if __name__ == "__main__":
    save_and_share()
EOF

CMD ["python", "automation.py"]
