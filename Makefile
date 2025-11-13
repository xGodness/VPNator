venv:
	@cd backend && [ -d .venv ] || python3 -m venv .venv

install: venv
	@cd backend && .venv/bin/pip install -r requirements.txt

backend: venv install
	@cd backend && .venv/bin/uvicorn main:main --reload

build: venv install
	@cd backend && pyinstaller --onefile --add-data=scripts:scripts --name vpnator_server main.py
