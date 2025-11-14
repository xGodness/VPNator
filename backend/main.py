import logging
import webbrowser
import os

import threading

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from server import Server

from dotenv import load_dotenv


logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("server.log")
    ]
)


def open_browser():
      webbrowser.open_new("http://127.0.0.1:8000")


app = FastAPI()


@app.on_event("startup")
def on_startup():
    threading.Thread(target=open_browser, daemon=True).start()


def main() -> FastAPI:
    load_dotenv()

    dists_path = os.environ.get('WEB_DISTS_PATH') or "web/dist"

    server = Server()

    app.websocket("/ws")(server.endpoint)

    app.mount("/VPNator", StaticFiles(directory=dists_path))
    app.mount("/", StaticFiles(directory=dists_path, html = True))

    return app


if __name__ == "__main__":
    import uvicorn

    app = main()
    uvicorn.run(app, host="0.0.0.0", port=8000)
