"""API FastAPI do OneSaver — Fase 1 (Feed + Reels, sem login)."""

import logging

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from .cache import TTLCache
from .config import settings
from .instagram import ResolveError, auth_status, parse_url, resolve
from .schemas import ErrorResponse, ResolveRequest, ResolveResponse

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("onesaver")

limiter = Limiter(key_func=get_remote_address)
cache = TTLCache(settings.cache_ttl, settings.cache_max_entries)


def require_api_key(x_api_key: str | None = Header(default=None)) -> None:
    """Exige o header X-API-Key quando ONESAVER_API_KEY está configurado."""
    if settings.api_key and x_api_key != settings.api_key:
        raise HTTPException(status_code=401, detail="API key inválida ou ausente.")

app = FastAPI(
    title="OneSaver API",
    version="0.1.0",
    description="Resolve URLs públicas do Instagram (feed/reels) em links de download.",
)
app.state.limiter = limiter
app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RateLimitExceeded)
async def _rate_limit_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    return JSONResponse(
        status_code=429,
        content=ErrorResponse(error="rate_limited", detail="Muitas requisições. Aguarde.").model_dump(),
    )


@app.exception_handler(ResolveError)
async def _resolve_error_handler(request: Request, exc: ResolveError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status,
        content=ErrorResponse(error=exc.code, detail=exc.detail).model_dump(),
    )


@app.get("/health")
async def health() -> dict:
    return {"status": "ok", "auth": auth_status()}


@app.post("/resolve", response_model=ResolveResponse, dependencies=[Depends(require_api_key)])
@limiter.limit(settings.rate_limit)
async def resolve_endpoint(request: Request, body: ResolveRequest) -> ResolveResponse:
    # Valida cedo e usa o shortcode como chave de cache.
    _, shortcode = parse_url(body.url)

    cached = cache.get(shortcode)
    if cached is not None:
        logger.info("cache hit %s", shortcode)
        return cached

    logger.info("resolving %s", shortcode)
    result = resolve(body.url)
    cache.set(shortcode, result)
    return result
