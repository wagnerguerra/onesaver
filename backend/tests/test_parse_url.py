import pytest

from app.instagram import ResolveError, parse_url


@pytest.mark.parametrize(
    "url,kind,shortcode",
    [
        ("https://www.instagram.com/reel/ABC123_-x/", "reel", "ABC123_-x"),
        ("https://instagram.com/p/XyZ987/", "post", "XyZ987"),
        ("http://www.instagram.com/tv/Vid42/", "tv", "Vid42"),
        ("https://www.instagram.com/reels/ShOrT1/", "reel", "ShOrT1"),
        # com username no caminho e querystring
        ("https://www.instagram.com/someuser/reel/QwErTy/?igsh=abc", "reel", "QwErTy"),
        # link embutido em texto compartilhado
        ("Olha isso https://www.instagram.com/p/Inline9/ via Instagram", "post", "Inline9"),
    ],
)
def test_parse_url_valid(url, kind, shortcode):
    assert parse_url(url) == (kind, shortcode)


@pytest.mark.parametrize(
    "url",
    [
        "https://example.com/p/abc/",
        "https://www.instagram.com/someuser/",  # perfil, não post
        "not a url",
        "https://www.instagram.com/stories/user/123/",  # stories fora de escopo
        "",
    ],
)
def test_parse_url_invalid(url):
    with pytest.raises(ResolveError) as exc:
        parse_url(url)
    assert exc.value.code == "invalid_url"
    assert exc.value.status == 400
