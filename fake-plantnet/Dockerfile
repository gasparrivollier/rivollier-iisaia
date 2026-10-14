FROM docker.io/library/python:3.13-slim
RUN pip install --no-cache-dir uv
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/opt/venv PATH="/opt/venv/bin:$PATH" \
    RECORDED_RESPONSE=/app/recorded/plantnet-identify-response.json
WORKDIR /app
COPY fake-plantnet/pyproject.toml fake-plantnet/uv.lock fake-plantnet/.python-version ./
RUN uv sync --frozen --no-dev --no-install-project
COPY fake-plantnet/server.py ./
COPY docs/examples/plantnet-identify-response.json /app/recorded/
EXPOSE 8100
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8100"]
