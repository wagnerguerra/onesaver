import app.cache as cache_module
from app.cache import TTLCache


class FakeClock:
    def __init__(self):
        self.now = 1000.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


def _patch_clock(monkeypatch):
    clock = FakeClock()
    monkeypatch.setattr(cache_module.time, "monotonic", clock)
    return clock


def test_get_set_roundtrip(monkeypatch):
    _patch_clock(monkeypatch)
    c = TTLCache(ttl_seconds=60)
    c.set("k", "v")
    assert c.get("k") == "v"
    assert c.get("missing") is None


def test_expiry(monkeypatch):
    clock = _patch_clock(monkeypatch)
    c = TTLCache(ttl_seconds=60)
    c.set("k", "v")
    clock.advance(59)
    assert c.get("k") == "v"
    clock.advance(2)  # passou do TTL
    assert c.get("k") is None


def test_lru_eviction_by_max_entries(monkeypatch):
    _patch_clock(monkeypatch)
    c = TTLCache(ttl_seconds=999, max_entries=2)
    c.set("a", 1)
    c.set("b", 2)
    c.get("a")  # 'a' vira o mais recente; 'b' fica como menos usado
    c.set("c", 3)  # excede o limite -> evita 'b'
    assert c.get("b") is None
    assert c.get("a") == 1
    assert c.get("c") == 3


def test_expired_evicted_on_set(monkeypatch):
    clock = _patch_clock(monkeypatch)
    c = TTLCache(ttl_seconds=10, max_entries=10)
    c.set("old", 1)
    clock.advance(20)  # 'old' expira
    c.set("new", 2)  # set dispara limpeza de expirados
    assert c.get("old") is None
    assert c.get("new") == 2
