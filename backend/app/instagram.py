"""Resolução de mídia do Instagram via yt-dlp, com pool de cookies e proxy.

A extração fica isolada aqui de propósito: quando o Instagram muda endpoints,
basta atualizar o yt-dlp (e, se preciso, este módulo) sem tocar no app cliente.
"""

import os
import re
import threading
import time

from yt_dlp import YoutubeDL
from yt_dlp.utils import DownloadError

from .config import settings
from .cookies import CookiePool
from .schemas import MediaItem, ResolveResponse

# Aceita /p/, /reel/, /reels/ e /tv/ de instagram.com (com ou sem www).
_URL_RE = re.compile(
    r"https?://(?:www\.)?instagram\.com/(?:[^/]+/)?(p|reel|reels|tv)/(?P<shortcode>[A-Za-z0-9_-]+)",
    re.IGNORECASE,
)

_TYPE_MAP = {"p": "post", "reel": "reel", "reels": "reel", "tv": "tv"}

# Pool de cookies e rotação de proxy compartilhados pelo processo.
pool = CookiePool(settings.cookies_file, settings.cookies_dir, settings.cookie_cooldown)
_proxy_idx = 0
_proxy_lock = threading.Lock()


class ResolveError(Exception):
    """Erro de domínio mapeado para resposta HTTP amigável."""

    def __init__(self, code: str, status: int, detail: str | None = None) -> None:
        super().__init__(detail or code)
        self.code = code
        self.status = status
        self.detail = detail


def parse_url(url: str) -> tuple[str, str]:
    """Valida a URL e retorna (tipo, shortcode). Lança ResolveError se inválida."""
    match = _URL_RE.search(url.strip())
    if not match:
        raise ResolveError("invalid_url", 400, "URL não é um post/reel/tv do Instagram.")
    kind = _TYPE_MAP.get(match.group(1).lower(), "unknown")
    return kind, match.group("shortcode")


def _next_proxy() -> str | None:
    proxies = settings.proxy_list()
    if not proxies:
        return None
    global _proxy_idx
    with _proxy_lock:
        proxy = proxies[_proxy_idx % len(proxies)]
        _proxy_idx += 1
    return proxy


def _ydl_opts(cookiefile: str | None, proxy: str | None) -> dict:
    opts: dict = {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "skip_download": True,
        "extract_flat": False,
    }
    if proxy:
        opts["proxy"] = proxy
    if cookiefile and os.path.isfile(cookiefile):
        opts["cookiefile"] = cookiefile
    return opts


def _classify(exc: DownloadError) -> ResolveError:
    msg = str(exc).lower()
    if "empty media response" in msg or "cookies" in msg or "login" in msg:
        return ResolveError(
            "auth_required",
            403,
            "O Instagram exigiu sessão autenticada para este conteúdo "
            "(IP bloqueado ou post login-gated). Configure cookies e/ou proxy.",
        )
    if "private" in msg or "not available" in msg or "unavailable" in msg:
        return ResolveError("unavailable", 404, "Conteúdo privado, removido ou indisponível.")
    if "rate" in msg or "429" in msg:
        return ResolveError("rate_limited", 429, "Limite do Instagram atingido. Tente mais tarde.")
    return ResolveError("extract_failed", 502, "Falha ao extrair a mídia.")


def _format_quality(fmt: dict) -> str:
    height = fmt.get("height")
    if height:
        return f"{height}p"
    if fmt.get("vcodec") in (None, "none"):
        return "audio"
    return fmt.get("format_id", "media")


def _medias_from_info(info: dict) -> list[MediaItem]:
    """Constrói a lista de mídias a partir do dict do yt-dlp.

    Prioriza formatos com vídeo, deduplicando por altura e mantendo o maior
    arquivo. Faz fallback para a URL direta quando não há lista de formatos.
    """
    formats = info.get("formats") or []
    by_height: dict[int | None, MediaItem] = {}

    for fmt in formats:
        url = fmt.get("url")
        if not url:
            continue
        if fmt.get("vcodec") in (None, "none"):
            continue
        height = fmt.get("height")
        size = fmt.get("filesize") or fmt.get("filesize_approx")
        item = MediaItem(
            quality=_format_quality(fmt),
            ext=fmt.get("ext") or "mp4",
            url=url,
            width=fmt.get("width"),
            height=height,
            filesize=size,
            has_audio=fmt.get("acodec") not in (None, "none"),
        )
        existing = by_height.get(height)
        if existing is None or (size or 0) > (existing.filesize or 0):
            by_height[height] = item

    medias = list(by_height.values())
    medias.sort(key=lambda m: (m.height or 0), reverse=True)

    if not medias and info.get("url"):
        medias = [
            MediaItem(
                quality=_format_quality(info),
                ext=info.get("ext") or "mp4",
                url=info["url"],
                width=info.get("width"),
                height=info.get("height"),
                filesize=info.get("filesize") or info.get("filesize_approx"),
            )
        ]
    return medias


def _build_result(kind: str, shortcode: str, info: dict) -> ResolveResponse:
    if not info:
        raise ResolveError("extract_failed", 502, "yt-dlp não retornou dados.")

    # Carrossel: yt-dlp pode devolver playlist; pega a primeira entrada com mídia.
    if info.get("_type") == "playlist":
        entries = [e for e in (info.get("entries") or []) if e]
        if not entries:
            raise ResolveError("unavailable", 404, "Sem mídia disponível no conteúdo.")
        info = entries[0]

    medias = _medias_from_info(info)
    if not medias:
        raise ResolveError("no_media", 404, "Nenhuma mídia de vídeo encontrada nesta URL.")

    return ResolveResponse(
        type=kind,
        shortcode=shortcode,
        author=info.get("uploader") or info.get("channel") or info.get("uploader_id"),
        title=(info.get("title") or info.get("description") or "")[:140] or None,
        thumbnail=info.get("thumbnail"),
        medias=medias,
    )


# Erros transitórios: vale repetir com backoff (rate-limit do IP é intermitente).
_RETRYABLE = ("auth_required", "rate_limited", "extract_failed")


def resolve(url: str) -> ResolveResponse:
    """Resolve uma URL pública em metadados + URLs de download.

    Tenta com cookies do pool (rotacionando e colocando em cooldown os que
    falham por auth/rate-limit) e, em falhas transitórias do IP de datacenter,
    repete com backoff exponencial. Lança ResolveError ao esgotar as tentativas.
    """
    kind, shortcode = parse_url(url)

    # Ao menos 1 tentativa; cobre tanto a rotação de cookies quanto os retries.
    max_attempts = max(pool.size(), settings.resolve_retries, 1)
    last_error: ResolveError | None = None

    for attempt in range(max_attempts):
        cookie = pool.acquire()  # None = sem cookie saudável → tenta anônimo
        proxy = _next_proxy()
        try:
            with YoutubeDL(_ydl_opts(cookie, proxy)) as ydl:
                info = ydl.extract_info(url, download=False)
        except DownloadError as exc:
            err = _classify(exc)
            # Falha de sessão: penaliza o cookie para sair da rotação por um tempo.
            if cookie and err.code in ("auth_required", "rate_limited"):
                pool.report_failure(cookie)
            last_error = err
            # Backoff e nova tentativa quando o erro é transitório.
            if err.code in _RETRYABLE and attempt < max_attempts - 1:
                time.sleep(min(settings.resolve_backoff * (2**attempt), 8.0))
                continue
            raise err from exc

        if cookie:
            pool.report_success(cookie)
        return _build_result(kind, shortcode, info)

    raise last_error or ResolveError(
        "auth_required", 403, "Nenhum cookie saudável disponível no momento."
    )


def auth_status() -> dict:
    """Status do pool de cookies e da rotação de proxy, exposto no /health."""
    return {
        "cookies": pool.status(),
        "proxies": len(settings.proxy_list()),
    }
