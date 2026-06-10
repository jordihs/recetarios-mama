"""Backend entry point.

Launches the local API bound to 127.0.0.1, announces the chosen port on stdout
(`RECETARIOS_PORT=<n>` handshake), and exits if the parent process disappears.
"""

import argparse
import os
import socket
import sys
import threading
import time
from pathlib import Path

import uvicorn
from platformdirs import user_data_dir

from recetarios.api.app import create_app


def _default_data_dir() -> Path:
    return Path(user_data_dir("recetarios-mama", appauthor=False))


def _watch_parent(parent_pid: int) -> None:
    import psutil

    def loop() -> None:
        while True:
            if not psutil.pid_exists(parent_pid):
                os._exit(0)
            time.sleep(2.0)

    threading.Thread(target=loop, daemon=True).start()


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(prog="recetarios")
    parser.add_argument("--port", type=int, default=0, help="0 picks an ephemeral port")
    parser.add_argument("--data-dir", type=Path, default=None)
    parser.add_argument("--parent-pid", type=int, default=None)
    args = parser.parse_args(argv)

    data_dir = args.data_dir or _default_data_dir()
    data_dir.mkdir(parents=True, exist_ok=True)

    if args.parent_pid:
        _watch_parent(args.parent_pid)

    app = create_app(data_dir)

    # Bind the socket ourselves so the real port is known before serving.
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("127.0.0.1", args.port))
    port = sock.getsockname()[1]
    print(f"RECETARIOS_PORT={port}", flush=True)

    @app.post("/shutdown")
    async def shutdown():
        threading.Thread(target=lambda: (time.sleep(0.2), os._exit(0)), daemon=True).start()
        return {"status": "stopping"}

    config = uvicorn.Config(app, log_level="warning")
    server = uvicorn.Server(config)
    try:
        server.run(sockets=[sock])
    except KeyboardInterrupt:
        pass
    sys.exit(0)


if __name__ == "__main__":
    main()
