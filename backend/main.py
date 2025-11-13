import logging

from fastapi import FastAPI

from .server import Server

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("./backend/server.log")
    ]
)


def main() -> FastAPI:
    app = FastAPI()
    server = Server()
    app.websocket("/ws")(server.endpoint)
    return app


if __name__ == "__main__":
    main()
