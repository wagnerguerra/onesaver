import pytest
from yt_dlp.utils import DownloadError

import app.instagram as ig
from app.cookies import CookiePool
from app.instagram import (
    ResolveError,
    _build_result,
    _classify,
    _medias_from_info,
)


# --- _classify ---


@pytest.mark.parametrize(
    "message,code,status",
    [
        ("Instagram sent an empty media response", "auth_required", 403),
        ("Login required to access this", "auth_required", 403),
        ("use --cookies to authenticate", "auth_required", 403),
        ("This account is private", "unavailable", 404),
        ("Requested content is not available", "unavailable", 404),
        ("HTTP Error 429: rate-limit reached", "rate_limited", 429),
        ("some totally unknown failure", "extract_failed", 502),
    ],
)
def test_classify(message, code, status):
    err = _classify(DownloadError(message))
    assert err.code == code
    assert err.status == status


# --- _medias_from_info ---


def test_medias_sorted_and_filtered():
    info = {
        "formats": [
            {"url": "u720", "ext": "mp4", "height": 720, "width": 1280,
             "vcodec": "h264", "acodec": "aac", "filesize_approx": 500},
            {"url": "u1080", "ext": "mp4", "height": 1080, "width": 1920,
             "vcodec": "h264", "acodec": "aac", "filesize": 1000},
            {"url": "audio", "ext": "m4a", "vcodec": "none", "acodec": "aac"},
        ]
    }
    medias = _medias_from_info(info)
    assert [m.quality for m in medias] == ["1080p", "720p"]  # ordenado desc
    assert all(m.has_audio for m in medias)
    assert medias[0].filesize == 1000


def test_medias_dedup_keeps_largest():
    info = {
        "formats": [
            {"url": "small", "ext": "mp4", "height": 1080, "vcodec": "h264",
             "acodec": "aac", "filesize": 100},
            {"url": "big", "ext": "mp4", "height": 1080, "vcodec": "h264",
             "acodec": "aac", "filesize": 999},
        ]
    }
    medias = _medias_from_info(info)
    assert len(medias) == 1
    assert medias[0].url == "big"


def test_medias_fallback_to_direct_url():
    info = {"url": "direct", "ext": "mp4", "height": 480}
    medias = _medias_from_info(info)
    assert len(medias) == 1
    assert medias[0].url == "direct"
    assert medias[0].quality == "480p"


# --- _build_result ---


def test_build_result_playlist_picks_first_entry():
    entry = {
        "formats": [{"url": "u", "ext": "mp4", "height": 720,
                     "vcodec": "h264", "acodec": "aac"}],
        "uploader": "alice",
        "title": "hello",
        "thumbnail": "thumb",
    }
    info = {"_type": "playlist", "entries": [entry]}
    res = _build_result("post", "SC1", info)
    assert res.author == "alice"
    assert res.shortcode == "SC1"
    assert res.medias[0].quality == "720p"


def test_build_result_no_media_raises():
    with pytest.raises(ResolveError) as exc:
        _build_result("reel", "SC2", {"formats": []})
    assert exc.value.code == "no_media"


# --- resolve() com pool + yt-dlp mockado ---


def _make_fake_ydl(handler):
    class _FakeYDL:
        def __init__(self, opts):
            self.opts = opts

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def extract_info(self, url, download=False):
            return handler(self.opts, url)

    return _FakeYDL


def _cookies_dir(tmp_path, names):
    d = tmp_path / "cookies"
    d.mkdir()
    for n in names:
        (d / n).write_text("# cookies\n")
    return str(d)


def test_resolve_rotates_to_healthy_cookie(tmp_path, monkeypatch):
    cdir = _cookies_dir(tmp_path, ["a.txt", "b.txt"])
    monkeypatch.setattr(ig, "pool", CookiePool("", cdir, cooldown=100))

    def handler(opts, url):
        cf = opts.get("cookiefile") or ""
        if cf.endswith("a.txt"):
            raise DownloadError("Instagram sent an empty media response")
        return {
            "formats": [{"url": "ok", "ext": "mp4", "height": 720,
                         "vcodec": "h264", "acodec": "aac"}],
            "uploader": "bob",
            "title": "vid",
            "thumbnail": "t",
        }

    monkeypatch.setattr(ig, "YoutubeDL", _make_fake_ydl(handler))

    res = ig.resolve("https://www.instagram.com/reel/Good1/")
    assert res.shortcode == "Good1"
    assert res.medias[0].quality == "720p"
    # o cookie que falhou ficou em cooldown
    assert ig.pool.available() == 1


def test_resolve_anonymous_failure_raises_auth_required(tmp_path, monkeypatch):
    monkeypatch.setattr(ig, "pool", CookiePool("", "", cooldown=100))

    def handler(opts, url):
        raise DownloadError("empty media response")

    monkeypatch.setattr(ig, "YoutubeDL", _make_fake_ydl(handler))

    with pytest.raises(ResolveError) as exc:
        ig.resolve("https://www.instagram.com/p/Anon1/")
    assert exc.value.code == "auth_required"
    assert exc.value.status == 403


def test_resolve_success_reports_pool_success(tmp_path, monkeypatch):
    cdir = _cookies_dir(tmp_path, ["a.txt"])
    monkeypatch.setattr(ig, "pool", CookiePool("", cdir, cooldown=100))

    def handler(opts, url):
        return {
            "formats": [{"url": "ok", "ext": "mp4", "height": 1080,
                         "vcodec": "h264", "acodec": "aac"}],
            "uploader": "x",
        }

    monkeypatch.setattr(ig, "YoutubeDL", _make_fake_ydl(handler))
    res = ig.resolve("https://www.instagram.com/reel/S/")
    assert res.medias[0].quality == "1080p"
    assert ig.pool.available() == 1
