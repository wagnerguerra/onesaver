# OneSaver — Backend (Fase 1)

API FastAPI que resolve URLs públicas do Instagram (feed/reels) em links de download,
usando `yt-dlp`. Sem login. A extração fica isolada para sobreviver às mudanças do Instagram.

## Rodando localmente

```bash
cd backend
python -m venv .venv
# Windows PowerShell:
.venv\Scripts\Activate.ps1
# Linux/macOS:
# source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env          # opcional; ajuste o proxy se tiver
uvicorn app.main:app --reload --port 8000
```

Docs interativas: http://localhost:8000/docs

## Endpoints

### `GET /health`
```json
{ "status": "ok" }
```

### `POST /resolve`
Request:
```json
{ "url": "https://www.instagram.com/reel/XXXXXXXXXXX/" }
```
Response:
```json
{
  "type": "reel",
  "shortcode": "XXXXXXXXXXX",
  "author": "username",
  "title": "...",
  "thumbnail": "https://...",
  "medias": [
    { "quality": "1080p", "ext": "mp4", "url": "https://...cdninstagram...", "height": 1920, "filesize": 1234567, "has_audio": true }
  ]
}
```

Erros retornam `{ "error": "<código>", "detail": "..." }` com status apropriado
(`invalid_url` 400, `unavailable` 404, `rate_limited` 429, `extract_failed` 502).

### Teste rápido
```bash
curl -X POST http://localhost:8000/resolve \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.instagram.com/reel/CtjW...."}'
```

## Testes
Suíte `pytest` (sem rede — yt-dlp é mockado):
```bash
pip install -r requirements-dev.txt
pytest
```
Ou via Docker, sem Python local:
```bash
docker run --rm -v "$PWD":/work -w /work backend-api:latest \
  sh -c "pip install -q pytest httpx && pytest"
```
Cobre: `parse_url`, cache (TTL + LRU), pool de cookies (rotação/cooldown),
classificação de erros, montagem de mídia, retry da resolução e os endpoints
(`/health`, `/resolve`, cache, API key).

## Notas
- **Proxy residencial** (`ONESAVER_PROXY`) é recomendado em produção: o Instagram bloqueia IPs de datacenter.
- **Cache** por shortcode em memória (TTL configurável). Trocar por Redis para multi-instância.
- Manter `yt-dlp` atualizado é o que absorve as mudanças de endpoint do Instagram.
- Stories **não** são suportados nesta fase (exigem sessão autenticada).
