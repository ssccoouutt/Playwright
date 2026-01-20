FROM python:3.11-slim

# Install ALL dependencies that Playwright needs
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libx11-6 libxcb1 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libgbm1 libasound2 \
    libcups2 libxkbcommon0 \  # ← THESE WERE MISSING
    fonts-liberation fonts-unifont \
    libpangocairo-1.0-0 libpango-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Playwright
RUN pip install playwright==1.40.0

# Install Chromium browser
RUN playwright install chromium

# Create automation script
RUN cat > automation.py << 'EOF'
from playwright.sync_api import sync_playwright
import os
from datetime import datetime

print("=" * 60)
print("🚀 PLAYWRIGHT AUTOMATION - WITH ALL DEPENDENCIES")
print("=" * 60)

try:
    # Launch browser with more options
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=['--no-sandbox', '--disable-dev-shm-usage']
        )
        
        print("✅ Browser launched!")
        
        page = browser.new_page(viewport={'width': 1920, 'height': 1080})
        
        # Take Google screenshot
        print("🌐 Opening Google...")
        page.goto("https://google.com", wait_until="networkidle", timeout=30000)
        page.screenshot(path="google.png", full_page=True)
        print("✅ google.png saved")
        
        # Take GitHub screenshot
        print("🌐 Opening GitHub...")
        page.goto("https://github.com")
        page.screenshot(path="github.png")
        print("✅ github.png saved")
        
        browser.close()
        
        # List files
        print("\n📁 Files created:")
        for file in os.listdir('.'):
            if file.endswith('.png'):
                size = os.path.getsize(file)
                print(f"  📸 {file} ({size:,} bytes)")
                
except Exception as e:
    print(f"\n❌ ERROR: {e}")
    print("\nDebug info:")
    print(f"Python: {sys.version}")
    print(f"Playwright version: {p.__version__ if 'p' in locals() else 'N/A'}")

print("\n" + "=" * 60)
print("🎉 AUTOMATION COMPLETED!")
print("=" * 60)
EOF

CMD ["python", "automation.py"]
