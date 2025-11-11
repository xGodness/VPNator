from fastapi import FastAPI

from .server import Server


def main() -> FastAPI:
    app = FastAPI()
    server = Server()
    app.websocket("/ws")(server.endpoint)
    return app


if __name__ == "__main__":
    main()
