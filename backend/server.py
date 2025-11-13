import logging
from asyncio import to_thread
from enum import Enum
from typing import List

import os
import sys

from fastapi import WebSocket
from starlette.websockets import WebSocketDisconnect

from command_executor import SSHConfig, CommandExecutor, ExecutionException

STATUS_REPORT_PREFIX = "# VPNATOR-STATUS-REPORT "
SET_USER_VARS_SUFFIX = "# VPNATOR-SET-USER-VARS"
SAVE_OUTPUT = "# VPNATOR-SAVE-OUTPUT"
COMPLETE = "VPNATOR-COMPLETE"

logger = logging.getLogger(__name__)


class VPNType(Enum):
    OPENCONNECT = "openconnect"
    OPENVPN = "openvpn"
    OUTLINE = "outline"


class Server:
    async def endpoint(self, websocket: WebSocket):
        await websocket.accept()
        try:
            while True:
                data = await websocket.receive_text()
                if data.startswith("install"):
                    args = data[8:].strip().split(" ")
                    await self.process_install(args=args, websocket=websocket)
        except WebSocketDisconnect:
            logger.info("WebSocket client disconnected")
        except Exception as e:
            logger.error(f"Unexpected error in WebSocket endpoint: {e}", exc_info=True)

    # cmd format: install <vpn_type: ['openconnect', 'openvpn', 'outline']> <host> <username> <password> [account_username] [account_password]
    @staticmethod
    async def process_install(args: List[str], websocket: WebSocket) -> None:
        try:
            vpn_type = VPNType(args[0])
        except ValueError:
            try:
                await websocket.send_text(f"Неизвестный тип VPN: {args[0]}")
            except WebSocketDisconnect:
                logger.info("WebSocket disconnected")
            return

        executor = None
        try:
            config = SSHConfig.create(host=args[1], username=args[2], password=args[3])
            executor = CommandExecutor(config=config)
            executor.connect()
        except ExecutionException as e:
            try:
                await websocket.send_text(e.message)
            except WebSocketDisconnect:
                logger.info("WebSocket disconnected")
            return
        
        try:
            with open(resource_path(f"scripts/{vpn_type.value}.sh"), "r") as file:
                save_ovpn = False
                for line in file:
                    line = line.strip()
                    if line.startswith(STATUS_REPORT_PREFIX):
                        report_msg = line.split(STATUS_REPORT_PREFIX)[1]
                        logger.info(report_msg)
                        try:
                            await websocket.send_text(report_msg)
                        except WebSocketDisconnect:
                            logger.info("WebSocket disconnected during status reporting")
                            return
                        continue
                    if line.startswith("#") or line.isspace():
                        continue

                    cmd = line
                    if line.endswith(SET_USER_VARS_SUFFIX):
                        if len(args) < 6:
                            err_msg = "Не установлены требуемые параметры аккаунта для подключения к VPN: имя и пароль"
                            logger.error(err_msg)
                            try:
                                await websocket.send_text(err_msg)
                            except WebSocketDisconnect:
                                logger.info("WebSocket disconnected")
                            return
                        acc_username = args[4]
                        acc_password = args[5]
                        cmd = f"OCSERV_USER=\"{acc_username}\" OCSERV_PASS=\"{acc_password}\" {cmd}"
                    elif line.endswith(SAVE_OUTPUT):
                        save_ovpn = True

                    result = await to_thread(executor.execute, cmd)
                    if result.code != 0:
                        err_msg = f"Ошибка в процессе установки: " + result.stderr
                        logger.error(err_msg)
                        try:
                            await websocket.send_text(err_msg)
                        except WebSocketDisconnect:
                            logger.info("WebSocket disconnected during error reporting")
                        return
                    else:
                        logger.info(result.stdout)
                        if save_ovpn:
                            save_ovpn = False
                            with open("client.ovpn" if vpn_type == VPNType.OPENVPN else "outline-key.txt", "w") as out:
                                out.write(result.stdout)
        except FileNotFoundError as e:
            logger.error(e)
            try:
                await websocket.send_text("Такой протокол еще не поддержан")
            except WebSocketDisconnect:
                logger.info("WebSocket disconnected")
            return
        finally:
            try:
                await websocket.send_text(COMPLETE)
            except WebSocketDisconnect:
                logger.info("WebSocket disconnected before sending completion")

            if executor is not None:
                try:
                    executor.shutdown()
                except Exception as e:
                    logger.warning(f"Error shutting down executor: {e}")


def resource_path(relative_path):
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

