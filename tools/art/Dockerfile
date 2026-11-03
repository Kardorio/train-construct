# Blender 4.5's Python module requires CPython 3.11.
FROM python:3.11-slim-bookworm AS builder
COPY --from=ghcr.io/astral-sh/uv:0.12.0 /uv /usr/local/bin/uv
WORKDIR /build
COPY requirements.txt ./
RUN uv venv --python /usr/local/bin/python /opt/art && \
    uv pip install --python /opt/art/bin/python --requirement requirements.txt

FROM python:3.11-slim-bookworm
ARG BUILD_TIMESTAMP="1970-01-01T00:00:00+00:00"
ARG COMMIT_HASH="00000000-dirty"
ARG PROJECT_URL="https://github.com/Kardorio/train-construct"
ARG VERSION="4.5.15"
LABEL org.opencontainers.image.source=${PROJECT_URL} \
      org.opencontainers.image.created=${BUILD_TIMESTAMP} \
      org.opencontainers.image.version=${VERSION} \
      org.opencontainers.image.revision=${COMMIT_HASH}
RUN apt-get update && apt-get install --yes --no-install-recommends \
    libegl1 libgl1 libgomp1 libice6 libsm6 libx11-6 libxext6 libxfixes3 \
    libxi6 libxkbcommon0 libxrender1 libxxf86vm1 && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /opt/art /opt/art
ENV PATH="/opt/art/bin:$PATH" \
    PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 HOME=/tmp \
    OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 \
    VERSION=${VERSION} COMMIT_HASH=${COMMIT_HASH} \
    BUILD_TIMESTAMP=${BUILD_TIMESTAMP} PROJECT_URL=${PROJECT_URL}
WORKDIR /workspace
USER 65532:65532
ENTRYPOINT ["python", "tools/art/render_depot.py"]
