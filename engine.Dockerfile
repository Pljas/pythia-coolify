# PYTHIA oracle engine (FastAPI, port 8088) — cloned from upstream at build time.
FROM python:3.11-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN git clone --depth=1 https://github.com/jangles-byte/Pythia.git .

# Mirrors pyproject [project.dependencies] (repo uses uv, image uses pip).
# Keep in sync when upstream bumps deps.
RUN pip install --no-cache-dir \
    "fastapi>=0.115" \
    "uvicorn[standard]>=0.30" \
    "httpx>=0.27" \
    "python-dotenv>=1.0" \
    "pydantic>=2.7" \
    "mcp>=1.2"

ENV ENGINE_HOST=0.0.0.0 \
    ENGINE_PORT=8088

EXPOSE 8088
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1:8088/health || exit 1

CMD ["python", "-m", "engine.run"]
