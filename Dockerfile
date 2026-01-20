FROM python:3.11-slim

# Install Chrome dependencies (minimal set)
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libx11-6 libxcb1 libxcomposite1 \
    libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libgbm1 libasound2 \
    fonts-liberation libpangocairo-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Create requirements.txt INSIDE the container
RUN echo "playwright==1.40.0" > requirements.txt

# Install Playwright
RUN pip install --no-cache-dir -r requirements.txt

# Install Chrome browser
RUN playwright install chromium --with-deps

# Create the Python script INSIDE the container
RUN cat > automation.py << 'EOF'
from playwright.sync_api import sync_playwright
import time
from datetime import datetime
import os

print("=" * 50)
print("🤖 PLAYWRIGHT AUTOMATION STARTED")
print("=" * 50)
print(f"Time: {datetime.now()}")
print(f"Working dir: {os.getcwd()}")
print()

# Take Google screenshot
print("📸 Step 1: Taking Google screenshot...")
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page(viewport={'width': 1920, 'height': 1080})
    
    page.goto("https://google.com", wait_until="networkidle")
    page.screenshot(path="google_homepage.png", full_page=True)
    
    print(f"✅ Saved: google_homepage.png")
    
    # Take another site screenshot
    print("📸 Step 2: Taking GitHub screenshot...")
    page.goto("https://github.com")
    page.screenshot(path="github.png", full_page=True)
    print(f"✅ Saved: github.png")
    
    browser.close()

print()
print("📁 Files created:")
for file in os.listdir('.'):
    if file.endswith('.png'):
        size = os.path.getsize(file)
        print(f"  - {file} ({size} bytes)")

print()
print("=" * 50)
print("🎉 AUTOMATION COMPLETED SUCCESSFULLY!")
print("=" * 50)
EOF

# Run the script
CMD ["python", "automation.py"]
