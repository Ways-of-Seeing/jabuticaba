#!/usr/bin/env python3
"""Proxy local de feeds RSS para o build web (os servidores de podcast não liberam CORS).

  python3 tool/screens/feed_proxy.py            # escuta em 127.0.0.1:8793
  flutter build web --dart-define=FEED_PROXY=http://localhost:8793/?url=

Só aceita URLs http(s) e só escuta em localhost. Não use em produção.
"""

import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_GET(self):
        url = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get("url", [""])[0]
        if not url.startswith(("http://", "https://")):
            self.send_error(400, "url inválida")
            return
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "jabuticaba-feed-proxy"})
            with urllib.request.urlopen(req, timeout=20) as r:
                body = r.read()
                ctype = r.headers.get("Content-Type", "application/xml")
        except Exception as e:  # noqa: BLE001
            self.send_error(502, str(e)[:200])
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", 8793), Handler).serve_forever()
