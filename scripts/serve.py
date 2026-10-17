#!/usr/bin/env python3
"""Serve the compiled game locally without exposing unrelated home files."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=8000)
parser.add_argument('--dist', action='store_true', help='serve the packaged dist directory')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
if args.dist:
    root = root / 'dist'
expected = root / ('game.js' if args.dist else '_build/js/release/build/yorkin/causal_loop/web/web.js')
if not expected.exists():
    raise SystemExit('Build missing. Run moon build --release (or python3 scripts/package.py for --dist).')

class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(Handler, directory=str(root)))
print(f'Game Demo: http://127.0.0.1:{args.port}  (Ctrl-C to stop)', flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    server.server_close()
