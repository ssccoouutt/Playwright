FROM python:3.11-slim

# Install minimal Chrome dependencies for Debian
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libx11-6 libxcb1 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libgbm1 libasound2 \
    fonts-liberation libpangocairo-1.0-0 \
    fonts-unifont \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Playwright WITHOUT --with-deps
RUN pip install playwright==1.40.0
RUN playwright install chromium

# Create the automation script
RUN cat > automation.py << 'EOF'
from playwright.sync_api import sync_playwright
import time
from datetime import datetime
import os

print("=" * 50)
print("🤖 PLAYWRIGHT AUTOMATION")
print("=" * 50)

# Test if Playwright works
print("Testing browser launch...")
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        print("✅ Browser launched successfully!")
        
        page = browser.new_page(viewport={'width': 1920, 'height': 1080})
        
        # Take Google screenshot
        print("🌐 Navigating to Google...")
        page.goto("https://google.com", wait_until="networkidle")
        page.screenshot(path="google.png")
        print("✅ google.png saved")
        
        # Take another
        print("🌐 Navigating to GitHub...")
        page.goto("https://github.com")
        page.screenshot(path="github.png")
        print("✅ github.png saved")
        
        browser.close()
        
        print("\n📁 Files created:")
        for file in os.listdir('.'):
            if file.endswith('.png'):
                size = os.path.getsize(file)
                print(f"  - {file} ({size} bytes)")
                
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 50)
print("🎉 DONE")
print("=" * 50)
EOF

# Run the script
CMD ["python", "automation.py"]
