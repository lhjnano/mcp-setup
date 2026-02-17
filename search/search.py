#!/usr/bin/env python3

from mcp.server.fastmcp import FastMCP
import requests
from playwright.sync_api import sync_playwright

SEARX_URL = "http://localhost:8080/search"

mcp = FastMCP("search")

def scrape(url):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(url, timeout=30000)
        text = page.inner_text("body")
        browser.close()
        return text[:2000]

@mcp.tool()
def web_search(query: str) -> str:
    res = requests.get(SEARX_URL, params={
        "q": query,
        "format": "json"
    })
    results = res.json()["results"][:3]

    output = []
    for r in results:
        try:
            text = scrape(r["url"])
            output.append(f"## {r['title']}\n{text}")
        except:
            continue

    return "\n\n".join(output)

if __name__ == "__main__":
    mcp.run()
