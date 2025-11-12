import os

from dotenv import load_dotenv

from ssh_client.command_executor import CommandExecutor, SSHConfig, ExecutionException


def load_config() -> SSHConfig:
    load_dotenv()
    return SSHConfig(
        os.getenv("REMOTE_HOST"),
        os.getenv("REMOTE_USERNAME"),
        os.getenv("REMOTE_PASSWORD")
    )


def main() -> None:
    config = load_config()
    executor = CommandExecutor(config)

    try:
        executor.connect()
    except ExecutionException as e:
        print(e.message)
        executor.shutdown()
        return

    print(executor.execute("ls -la"))


if __name__ == "__main__":
    main()
