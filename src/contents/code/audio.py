#!/usr/bin/env python3
"""Audio spectrum helper for the Spotify Lyrics widget.

Runs cava on the system's audio output and serves the latest frame of
frequency bars at http://127.0.0.1:<port>/bars as "v1;v2;...;vN" (0-1000).

Only one copy runs per port. It exits by itself when nothing has asked for
data for a while, so removing the widget (or turning the effects off) stops it.
"""

import argparse
import ctypes
import os
import signal
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

IDLE_EXIT_SECONDS = 20

CAVA_CONFIG = """
[general]
bars = {bars}
framerate = 60
autosens = 1

[input]
method = pipewire
source = auto

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = mono

[smoothing]
noise_reduction = 55
"""


def die_with_parent():
    # Linux: have the kernel send cava SIGTERM if this helper goes away.
    try:
        ctypes.CDLL("libc.so.6").prctl(1, signal.SIGTERM)  # PR_SET_PDEATHSIG
    except OSError:
        pass


CAVA = None


def stop(code):
    if CAVA and CAVA.poll() is None:
        CAVA.terminate()
    os._exit(code)


class State:
    def __init__(self, bars):
        self.frame = ";".join(["0"] * bars)
        self.last_request = time.monotonic()
        self.lock = threading.Lock()


def run_cava(state, bars):
    with tempfile.NamedTemporaryFile("w", suffix=".cava", delete=False) as cfg:
        cfg.write(CAVA_CONFIG.format(bars=bars))
        cfg_path = cfg.name
    global CAVA
    try:
        proc = CAVA = subprocess.Popen(
            ["cava", "-p", cfg_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            bufsize=1,
            preexec_fn=die_with_parent,
        )
        for line in proc.stdout:
            line = line.strip().rstrip(";")
            if line:
                with state.lock:
                    state.frame = line
        proc.wait()
    finally:
        os.unlink(cfg_path)
    # cava died (e.g. audio server restarted): let the widget relaunch us.
    stop(1)


def make_handler(state):
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            state.last_request = time.monotonic()
            if self.path != "/bars":
                self.send_error(404)
                return
            with state.lock:
                body = state.frame.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass

    return Handler


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=47615)
    parser.add_argument("--bars", type=int, default=48)
    args = parser.parse_args()

    if not shutil.which("cava"):
        print("cava is not installed", file=sys.stderr)
        sys.exit(2)

    state = State(args.bars)
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), make_handler(state))
    except OSError:
        sys.exit(0)  # already running

    threading.Thread(target=run_cava, args=(state, args.bars), daemon=True).start()
    threading.Thread(target=server.serve_forever, daemon=True).start()

    while time.monotonic() - state.last_request < IDLE_EXIT_SECONDS:
        time.sleep(2)
    stop(0)


if __name__ == "__main__":
    main()
