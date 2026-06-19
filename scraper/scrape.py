import os
from datetime import datetime
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import requests

load_dotenv()

API_URL = os.getenv("API_URL")
API_KEY = os.getenv("SCRAPER_API_KEY")


def scrape_gse():
    print(f"[{datetime.now()}] Starting scrape...")

    try:
        r = requests.get(
            "https://gsestockfeed.com/style2.php",
            headers={"User-Agent": "Mozilla/5.0"},
            timeout=30
        )
        r.raise_for_status()
    except Exception as e:
        print(f"Failed to fetch data: {e}")
        return

    soup = BeautifulSoup(r.text, "html.parser")
    stocks = []

    items = soup.select("li[id]")
    for item in items:
        li_id = item.get("id")
        if not li_id or li_id == "ticker_date":
            continue

        top_p = item.select_one("p.top")
        bottom_p = item.select_one("p.bottom")
        if not top_p or not bottom_p:
            continue

        try:
            top_text = top_p.get_text(separator=" ", strip=True)
            bottom_text = bottom_p.get_text(strip=True)

            # Format: "MTNGH 6.45, 0.01" or "EGH 39.00, -1.0"
            parts = top_text.split()
            if len(parts) < 2:
                continue

            symbol = parts[0]
            price_str = parts[1].replace(",", "")
            change_str = parts[2].replace(",", "") if len(parts) > 2 else "0"

            price = float(price_str)
            change = float(change_str)
            volume = int(bottom_text) if bottom_text.isdigit() else 0

            change_percent = 0
            if price > 0 and change != 0:
                prev_price = price - change
                if prev_price > 0:
                    change_percent = round((change / prev_price) * 100, 2)

            stocks.append({
                "symbol": symbol,
                "price": price,
                "change_value": change,
                "change_percent": change_percent,
                "volume": volume
            })
            print(f"  {symbol}: GHS {price}, change {change}, vol {volume}")

        except (ValueError, IndexError) as e:
            print(f"  Skipping {li_id}: {e}")
            continue

    print(f"\nScraped {len(stocks)} stocks")

    if stocks and API_URL and API_KEY:
        resp = requests.post(
            f"{API_URL}/api/scraper/prices",
            json=stocks,
            headers={"Content-Type": "application/json", "X-API-Key": API_KEY},
            timeout=30
        )
        print(f"API response: {resp.status_code} - {resp.text}")
    elif stocks:
        print("Stocks scraped successfully! (no API_URL/API_KEY in .env to send to)")
    else:
        print("No stocks found")


if __name__ == "__main__":
    scrape_gse()