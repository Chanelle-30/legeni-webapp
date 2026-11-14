# syntax=docker/dockerfile:1

# ============================================================
# Étape 1 : dépendances runtime communes
# ============================================================
FROM python:3.12-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ============================================================
# Étape 2 : lint + tests (docker build --target test)
# ============================================================
FROM base AS test
COPY requirements-dev.txt .
RUN pip install --no-cache-dir -r requirements-dev.txt
COPY pytest.ini .flake8 ./
COPY app.py ./
COPY tests ./tests
# Quality gates : flake8 + pytest avec couverture >= 80 % + rapport JUnit
RUN flake8 . \
 && pytest -q \
        --cov=. \
        --cov-report=term-missing \
        --cov-report=xml:reports/coverage.xml \
        --junitxml=reports/junit.xml \
        --cov-fail-under=80

# ============================================================
# Étape 3 : image finale de production (minimale, non-root)
# ============================================================
FROM base AS runtime
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="legeni-webapp" \
      org.opencontainers.image.version="${APP_VERSION}"
ENV APP_VERSION=${APP_VERSION} \
    PORT=5000

# Utilisateur non-root dédié
RUN useradd --create-home --uid 10001 appuser

COPY --chown=appuser:appuser app.py .

USER 10001

EXPOSE 5000

HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5000/health')"]

# CMD en forme exec → SIGTERM bien reçu par gunicorn (arrêt propre)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:app"]
