venv:
	@[ -d backend/.venv ] || python3 -m venv backend/.venv

install: venv
	@backend/.venv/bin/pip install -r backend/requirements.txt

backend: venv install
	@backend/.venv/bin/uvicorn backend.main:main --reload
