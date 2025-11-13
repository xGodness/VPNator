import logging

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from server import Server

import os

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("server.log")
    ]
)


def main() -> FastAPI:
    dists_path = os.environ['WEB_DISTS_PATH'] or "web/dist"

    app = FastAPI()
    server = Server()

    app.mount("/VPNator", StaticFiles(directory=dists_path))
    app.mount("/", StaticFiles(directory=dists_path, html = True))

    app.websocket("/ws")(server.endpoint)
    return app


if __name__ == "__main__":
    import uvicorn

    app = main()
    uvicorn.run(app, host="0.0.0.0", port=8000)
