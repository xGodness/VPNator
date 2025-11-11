from enum import Enum
from typing import List

from fastapi import WebSocket

from .command_executor import SSHConfig, CommandExecutor, ExecutionException


class VPNType(Enum):
    OPENCONNECT = "openconnect"
    XRAY = "xray"
    OUTLINE = "outline"


class Server:
    async def endpoint(self, websocket: WebSocket):
        await websocket.accept()
        while True:
            data = await websocket.receive_text()
            if data.startswith("install"):
                args = data[8:].strip().split(" ")
                await self.process_install(args=args, websocket=websocket)

    # cmd format: install <vpn_type: ['openconnect', 'xray', 'outline']> <host> <username> <password>
    @staticmethod
    async def process_install(args: List[str], websocket: WebSocket) -> None:
        try:
            vpn_type = VPNType(args[0])
        except KeyError:
            await websocket.send_text(f"Неизвестный тип VPN: {args[0]}")
            return

        try:
            config = SSHConfig(host=args[1], username=args[2], password=args[3])
            executor = CommandExecutor(config=config)
            executor.connect()
        except ExecutionException as e:
            await websocket.send_text(e.message)
            return

        with open(f"backend/scripts/{vpn_type.value}.sh", "r") as file:
            for line in file:
                if line.startswith("#") or line.isspace():
                    continue

                result = executor.execute(command=line)
                if result.code != 0:
                    await websocket.send_text(f"Ошибка в процессе установки: " + result.stderr)
                    executor.shutdown()
                    return
                else:
                    await websocket.send_text(result.stdout)
