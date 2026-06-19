import requests

response = requests.get("https://gse.com.gh", timeout=30)
print(f"Status: {response.status_code}")
print(f"Length: {len(response.text)} characters")

# Save to file so you can inspect it
with open("page.html", "w", encoding="utf-8") as f:
    f.write(response.text)

# Check if any <li id="MTNGH"> exists
if "MTNGH" in response.text:
    print("✓ Found stock data in HTML")
else:
    print("✗ Stock data NOT in HTML — it's loaded by JavaScript")