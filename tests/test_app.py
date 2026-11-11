import pytest

from app import MemoryCounter, create_app


class DownCounter(MemoryCounter):
    """Simule un Redis injoignable."""

    def ping(self):
        return False


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.2.3")
    monkeypatch.setenv("APP_ENV", "test")
    app = create_app(counter=MemoryCounter())
    return app.test_client()


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "ok"}


def test_ready_with_memory_counter(client):
    assert client.get("/ready").status_code == 200


def test_ready_returns_503_when_redis_down():
    client = create_app(counter=DownCounter()).test_client()
    assert client.get("/ready").status_code == 503


def test_index_shows_version_and_env(client):
    body = client.get("/").get_data(as_text=True)
    assert "Version 1.2.3" in body
    assert "test" in body


def test_visits_are_counted(client):
    client.get("/")
    body = client.get("/").get_data(as_text=True)
    assert "<b>2</b>" in body


def test_api_info(client):
    data = client.get("/api/info").get_json()
    assert data["app"] == "legeni-webapp"
    assert data["version"] == "1.2.3"
    assert data["hostname"]
