import logging
from asyncio import to_thread
from enum import Enum
from typing import List

from fastapi import WebSocket

from command_executor import SSHConfig, CommandExecutor, ExecutionException

STATUS_REPORT_PREFIX = "# VPNATOR-STATUS-REPORT "
SET_USER_VARS_SUFFIX = "# VPNATOR-SET-USER-VARS"
COMPLETE = "VPNATOR-COMPLETE"

logger = logging.getLogger(__name__)


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

    # cmd format: install <vpn_type: ['openconnect', 'xray', 'outline']> <host> <username> <password> [account_username] [account_password]
    @staticmethod
    async def process_install(args: List[str], websocket: WebSocket) -> None:
        try:
            vpn_type = VPNType(args[0])
        except ValueError:
            await websocket.send_text(f"Неизвестный тип VPN: {args[0]}")
            return

        try:
            config = SSHConfig(host=args[1], username=args[2], password=args[3])
            executor = CommandExecutor(config=config)
            executor.connect()
        except ExecutionException as e:
            await websocket.send_text(e.message)
            return

        with open(f"scripts/{vpn_type.value}.sh", "r") as file:
            for line in file:
                line = line.strip()
                if line.startswith(STATUS_REPORT_PREFIX):
                    report_msg = line.split(STATUS_REPORT_PREFIX)[1]
                    logger.info(report_msg)
                    await websocket.send_text(report_msg)
                    continue
                if line.startswith("#") or line.isspace():
                    continue

                cmd = line
                if line.endswith(SET_USER_VARS_SUFFIX):
                    if len(args) < 6:
                        err_msg = "Не установлены требуемые параметры аккаунта для подключения к VPN: имя и пароль"
                        logger.error(err_msg)
                        await websocket.send_text(err_msg)
                        await websocket.send_text(COMPLETE)
                        return
                    acc_username = args[4]
                    acc_password = args[5]
                    cmd = f"OCSERV_USER=\"{acc_username}\" OCSERV_PASS=\"{acc_password}\" {cmd}"

                result = await to_thread(executor.execute, cmd)
                if result.code != 0:
                    err_msg = f"Ошибка в процессе установки: " + result.stderr
                    logger.error(err_msg)
                    await websocket.send_text(err_msg)
                    await websocket.send_text(COMPLETE)
                    return
                else:
                    logger.info(result.stdout)

            await websocket.send_text(COMPLETE)
