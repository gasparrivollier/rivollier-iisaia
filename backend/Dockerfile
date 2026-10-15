FROM docker.io/library/python:3.13-slim
RUN pip install --no-cache-dir uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/opt/venv PATH="/opt/venv/bin:$PATH"
WORKDIR /app
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --no-install-project
COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app
EXPOSE 8000
# Wait for Postgres, migrate (idempotent), then serve.
CMD ["sh", "-c", "python -m app.wait_for_db && alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000"]
