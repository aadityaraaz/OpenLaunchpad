#!/usr/bin/env python3
"""Audit the public sitemap without storing copyrighted page bodies."""
import concurrent.futures
import datetime
import html.parser
import json
import pathlib
import urllib.request
import xml.etree.ElementTree as ET

BASE = 'https://launchosapp.com/'
class Page(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(); self.tag = ''; self.skip = 0; self.title = []; self.text = []; self.links = []
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'): self.skip += 1
        self.tag = tag
        if tag == 'a':
            for key, value in attrs:
                if key == 'href': self.links.append(value)
    def handle_endtag(self, tag):
        if tag in ('script', 'style'): self.skip = max(0, self.skip - 1)
        self.tag = ''
    def handle_data(self, data):
        if not self.skip:
            if self.tag == 'title': self.title.append(data)
            if data.strip(): self.text.append(data.strip())
def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'OpenLaunchpad-public-feature-review/0.1'})
    with urllib.request.urlopen(req, timeout=30) as response:
        return response.status, response.read().decode('utf-8', errors='replace')
status, sitemap = fetch(BASE + 'sitemap.xml')
root = ET.fromstring(sitemap)
urls = sorted(set(e.text for e in root.findall('{*}url/{*}loc')) | {BASE, BASE + 'features/'})
keywords = ['gesture', 'pinch', 'folder', 'uninstall', 'hot corner', 'F4', 'backup', 'pinyin', 'window', 'multi-select', 'Dock', 'alias', 'color', 'update', 'launchpad']
def review(url):
    try:
        status, body = fetch(url); page = Page(); page.feed(body)
        text = ' '.join(page.text).lower()
        return {'url': url, 'status': status, 'title': ''.join(page.title), 'text_characters': len(text), 'feature_topics': [term for term in keywords if term.lower() in text], 'internal_links': sorted(set(link for link in page.links if link.startswith('/') or link.startswith(BASE)))}
    except Exception as error: return {'url': url, 'error': str(error)}
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(review, urls))
output = {'reviewed_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'sitemap': BASE + 'sitemap.xml', 'pages': results}
path = pathlib.Path(__file__).resolve().parent.parent / 'docs/website-audit.json'
path.write_text(json.dumps(output, indent=2, ensure_ascii=False) + '\n')
failed = [r for r in results if r.get('status') != 200]
print(f'Reviewed {len(results)} sitemap pages; {len(failed)} failures. Audit: {path}')
for result in failed: print(result['url'], result.get('error', result.get('status')))
