import ipaddress
import logging
from dataclasses import dataclass
from typing import Mapping

from paramiko import SSHClient, AutoAddPolicy, AuthenticationException
from paramiko.ssh_exception import SSHException

logger = logging.getLogger(__name__)


@dataclass
class SSHConfig:
    host: str
    username: str
    password: str
    port: int = 22

    @classmethod
    def create(cls, host: str, username: str, password: str) -> "SSHConfig":
        """
        Create SSHConfig from host string.
        If host is valid IPv4, uses default port 22.
        If host is in format 'IPv4:port', parses the port.
        """
        port = 22
        parsed_host = host

        if ":" in host:
            parts = host.rsplit(":", 1)
            if len(parts) == 2:
                host_part, port_part = parts
                try:
                    port = int(port_part)
                    parsed_host = host_part
                except ValueError:
                    parsed_host = host
                    port = 22

        try:
            ipaddress.IPv4Address(parsed_host)
        except ValueError:
            pass

        return cls(host=parsed_host, username=username, password=password, port=port)


@dataclass
class ExecutionResult:
    code: int
    stdout: str
    stderr: str


class ExecutionException(Exception):
    def __init__(self, message="Что-то пошло не так"):
        self.message = "ssh | " + message
        super().__init__(self.message)


class CommandExecutor:
    def __init__(self, config: SSHConfig):
        self.host = config.host
        self.username = config.username
        self.password = config.password
        self.port = config.port
        self.client = SSHClient()

    def connect(self) -> None:
        self.client.set_missing_host_key_policy(AutoAddPolicy())
        try:
            self.client.connect(hostname=self.host,
                                port=self.port,
                                username=self.username,
                                password=self.password,
                                allow_agent=False,
                                look_for_keys=False)
        except AuthenticationException as e:
            _handle_exception(e, "Ошибка аутентификации: проверьте введенные данные")
        except SSHException as e:
            _handle_exception(e, "Ошибка подключения")
        except Exception as e:
            _handle_exception(e)

    def execute(self, command: str, environment: Mapping[str, str] | None = None) -> ExecutionResult:
        logger.info(f"executing: " + command)
        _, stdout_ch, stderr_ch = self.client.exec_command(command=command, environment=environment)
        code = stdout_ch.channel.recv_exit_status()
        return ExecutionResult(code=int(code), stdout=stdout_ch.read().decode(), stderr=stderr_ch.read().decode())

    def shutdown(self) -> None:
        self.client.close()


def _handle_exception(e: Exception, message: str | None = None) -> None:
    logger.error(e)
    if message is not None:
        raise ExecutionException(message)
    raise ExecutionException()

