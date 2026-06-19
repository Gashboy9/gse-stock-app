import os
from selenium import webdriver
from selenium.webdriver.edge.options import Options
from selenium.webdriver.edge.service import Service
import time

service = Service(executable_path="C:/Projects/gse-stock-app/scraper/msedgedriver.exe")
options = Options()
options.add_argument("--disable-gpu")
options.add_argument("--disable-software-rasterizer")
options.add_argument("--disable-extensions")
options.add_argument("--no-sandbox")
options.add_argument("--disable-features=VizDisplayCompositor")
options.add_argument("--disable-direct-composition")
options.add_argument("--enable-unsafe-swiftshader")

driver = webdriver.Edge(service=service, options=options)
driver.get("https://gse.com.gh")
time.sleep(10)

# Get all network requests the page tried to make
logs = driver.execute_script("""
    var entries = performance.getEntriesByType('resource');
    return entries.map(function(e) { return e.name; });
""")

print("All resource URLs loaded by the page:")
for url in logs:
    if 'ajax' in url or 'api' in url or 'json' in url or 'ticker' in url or 'stock' in url:
        print(f"  >>> {url}")

# Also check what scripts loaded
scripts = driver.execute_script("""
    return Array.from(document.querySelectorAll('script[src]')).map(s => s.src);
""")
print(f"\nScripts ({len(scripts)}):")
for s in scripts:
    print(f"  {s}")

# Check console errors
console_logs = driver.execute_script("return window.__ticker_data || 'no ticker_data variable';")
print(f"\nTicker data variable: {console_logs}")

driver.quit()