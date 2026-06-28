# Deploy do backend OneSaver

O backend é um container stateless. Recomendado rodá-lo atrás de um reverse proxy
com TLS. Abaixo, três caminhos. Em todos: **monte os cookies como secret** e
**configure proxy residencial** para produção.

## Variáveis principais
Veja `.env.example`. As mais importantes em produção:
- `ONESAVER_API_KEY` — protege o `/resolve` (o app envia `X-API-Key`).
- `ONESAVER_PROXIES` — lista de proxies residenciais (rotação).
- `ONESAVER_COOKIES_DIR=/secrets/cookies` — pool de contas-robô.
- `ONESAVER_CORS_ORIGINS` — restrinja às origens do seu app/web.

## Cookies (pool)
Coloque um ou mais arquivos Netscape em `backend/secrets/cookies/*.txt`
(um por conta-robô). Veja `COOKIES.md` para gerar. O pool rotaciona e coloca em
cooldown os que falham. Verifique em `/health`:
```json
{"status":"ok","auth":{"cookies":{"total":3,"available":3,"cooling_down":0},"proxies":2}}
```

---

## Opção A — VPS com Docker Compose (recomendado p/ começar)
```bash
# no servidor, dentro de backend/
cp .env.example .env          # edite API_KEY, PROXIES, CORS...
mkdir -p secrets/cookies      # coloque os *.txt aqui
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```
Coloque **Caddy** ou **Nginx** na frente para TLS (ex.: Caddy faz HTTPS automático).
Exemplo `Caddyfile`:
```
api.seudominio.com {
    reverse_proxy localhost:8000
}
```

## Opção B — Fly.io
```bash
fly launch --no-deploy            # gera fly.toml (porta interna 8000)
fly secrets set ONESAVER_API_KEY=... ONESAVER_PROXIES=...
# Cookies: use um volume ou monte via secret/arquivo no deploy.
fly deploy
```
Ajuste `fly.toml`: `internal_port = 8000` e um healthcheck em `/health`.

## Opção C — Railway / Render
- Aponte para `backend/Dockerfile`.
- Defina as variáveis de ambiente no painel.
- Exponha a porta 8000; configure healthcheck `/health`.
- Para cookies, use um *secret file* / volume montado em `/secrets`.

---

## Operação
- **Atualizar yt-dlp** periodicamente (absorve mudanças do Instagram):
  rebuild da imagem (o `requirements.txt` está pinado — suba a versão e rebuild)
  ou rode `pip install -U yt-dlp` no container e reinicie.
- **Monitorar** `/health`: se `available` cair a 0, os cookies expiraram/banidos
  → reexporte (`COOKIES.md`) e adicione novos `*.txt`.
- **Escala**: aumente `--workers` (compose prod) e/ou réplicas atrás do proxy.
  Para cache compartilhado entre réplicas, migrar `TTLCache` → Redis.
- **Custos**: o gargalo real é proxy residencial; cacheie agressivamente
  (`ONESAVER_CACHE_TTL`) para reduzir hits ao Instagram.
