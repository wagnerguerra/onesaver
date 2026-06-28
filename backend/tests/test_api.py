import pytest
from fastapi.testclient import TestClient

from app import main
from app.schemas import MediaItem, ResolveResponse


@pytest.fixture
def client():
    return TestClient(main.app)


def _fake_result(shortcode):
    return ResolveResponse(
        type="reel",
        shortcode=shortcode,
        author="tester",
        title="vid",
        thumbnail="thumb",
        medias=[MediaItem(quality="720p", ext="mp4", url="https://cdn/x.mp4")],
    )


def test_health(client):
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "ok"
    assert "cookies" in body["auth"]
    assert "proxies" in body["auth"]


def test_resolve_invalid_url(client):
    res = client.post("/resolve", json={"url": "not-instagram"})
    assert res.status_code == 400
    assert res.json()["error"] == "invalid_url"


def test_resolve_success(client, monkeypatch):
    monkeypatch.setattr(main, "resolve", lambda url: _fake_result("Succ1"))
    res = client.post(
        "/resolve", json={"url": "https://www.instagram.com/reel/Succ1/"}
    )
    assert res.status_code == 200
    body = res.json()
    assert body["shortcode"] == "Succ1"
    assert body["medias"][0]["quality"] == "720p"


def test_resolve_uses_cache(client, monkeypatch):
    calls = {"n": 0}

    def counting(url):
        calls["n"] += 1
        return _fake_result("Cache1")

    monkeypatch.setattr(main, "resolve", counting)
    url = "https://www.instagram.com/reel/Cache1/"
    first = client.post("/resolve", json={"url": url})
    second = client.post("/resolve", json={"url": url})
    assert first.status_code == second.status_code == 200
    assert calls["n"] == 1  # segunda chamada veio do cache


def test_api_key_required(client, monkeypatch):
    monkeypatch.setattr(main.settings, "api_key", "segredo")
    monkeypatch.setattr(main, "resolve", lambda url: _fake_result("Key1"))
    url = "https://www.instagram.com/reel/Key1/"

    # sem header -> 401
    assert client.post("/resolve", json={"url": url}).status_code == 401
    # header errado -> 401
    assert client.post(
        "/resolve", json={"url": url}, headers={"X-API-Key": "errado"}
    ).status_code == 401
    # header correto -> 200
    ok = client.post(
        "/resolve", json={"url": url}, headers={"X-API-Key": "segredo"}
    )
    assert ok.status_code == 200
