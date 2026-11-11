# syntax=docker/dockerfile:1
# ---------- Étape 1 : dépendances communes ----------
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
# On copie d'abord requirements.txt seul : cette couche reste en cache
# tant que les dépendances ne changent pas.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---------- Étape 2 : lint + tests (docker build --target test) ----------
FROM base AS test
COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY . .
RUN flake8 . && pytest -q

# ---------- Étape 3 : image finale de production ----------
FROM base AS runtime
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="legeni-webapp" \
      org.opencontainers.image.version="${APP_VERSION}"
ENV APP_VERSION=${APP_VERSION}
RUN useradd --create-home --uid 10001 appuser
COPY app.py .
USER appuser
EXPOSE 5000
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health')" || exit 1
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
