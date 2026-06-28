import app.cookies as cookies_module
from app.cookies import CookiePool


class FakeClock:
    def __init__(self):
        self.now = 0.0

    def __call__(self):
        return self.now

    def advance(self, seconds):
        self.now += seconds


def _patch_clock(monkeypatch):
    clock = FakeClock()
    monkeypatch.setattr(cookies_module.time, "monotonic", clock)
    return clock


def _make_dir(tmp_path, names):
    d = tmp_path / "cookies"
    d.mkdir()
    for n in names:
        (d / n).write_text("# netscape cookies\n")
    return str(d)


def test_discovery_single_and_dir(tmp_path, monkeypatch):
    _patch_clock(monkeypatch)
    single = tmp_path / "cookies.txt"
    single.write_text("x")
    cdir = _make_dir(tmp_path, ["b.txt", "a.txt", "ignore.json"])
    pool = CookiePool(str(single), cdir, cooldown=60)
    # arquivo único primeiro, depois *.txt do diretório em ordem; .json ignorado
    assert pool.size() == 3
    assert pool.available() == 3


def test_empty_pool_acquire_none(tmp_path, monkeypatch):
    _patch_clock(monkeypatch)
    pool = CookiePool("", "", cooldown=60)
    assert pool.size() == 0
    assert pool.acquire() is None


def test_round_robin(tmp_path, monkeypatch):
    _patch_clock(monkeypatch)
    cdir = _make_dir(tmp_path, ["a.txt", "b.txt"])
    pool = CookiePool("", cdir, cooldown=60)
    a = pool.acquire()
    b = pool.acquire()
    c = pool.acquire()
    assert {a, b} == {p for p in [a, b]}  # dois distintos
    assert a != b
    assert c == a  # volta ao começo


def test_cooldown_skips_failed_then_recovers(tmp_path, monkeypatch):
    clock = _patch_clock(monkeypatch)
    cdir = _make_dir(tmp_path, ["a.txt", "b.txt"])
    pool = CookiePool("", cdir, cooldown=100)
    first = pool.acquire()
    pool.report_failure(first)
    assert pool.available() == 1
    # próximas aquisições pulam o que falhou
    for _ in range(3):
        assert pool.acquire() != first
    # após o cooldown, volta a ficar disponível
    clock.advance(101)
    assert pool.available() == 2
    seen = {pool.acquire() for _ in range(2)}
    assert first in seen


def test_all_cooling_returns_none(tmp_path, monkeypatch):
    _patch_clock(monkeypatch)
    cdir = _make_dir(tmp_path, ["a.txt", "b.txt"])
    pool = CookiePool("", cdir, cooldown=100)
    pool.report_failure(str(__import__("pathlib").Path(cdir) / "a.txt"))
    pool.report_failure(str(__import__("pathlib").Path(cdir) / "b.txt"))
    assert pool.available() == 0
    assert pool.acquire() is None


def test_report_success_clears_cooldown(tmp_path, monkeypatch):
    _patch_clock(monkeypatch)
    cdir = _make_dir(tmp_path, ["a.txt"])
    pool = CookiePool("", cdir, cooldown=100)
    p = pool.acquire()
    pool.report_failure(p)
    assert pool.available() == 0
    pool.report_success(p)
    assert pool.available() == 1


def test_status_shape(tmp_path, monkeypatch):
    _patch_clock(monkeypatch)
    cdir = _make_dir(tmp_path, ["a.txt", "b.txt"])
    pool = CookiePool("", cdir, cooldown=100)
    pool.report_failure(pool.acquire())
    st = pool.status()
    assert st == {"total": 2, "available": 1, "cooling_down": 1}
