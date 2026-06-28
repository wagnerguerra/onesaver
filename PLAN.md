# OneSaver — Plano de Execução

App que baixa vídeos públicos do Instagram (Feed e Reels) sem login, inspirado no InSaver.
Lê o link da área de transferência / share sheet e disponibiliza o download.

## Decisões

| Tópico | Decisão |
|---|---|
| App cliente | **Flutter** (Android primeiro; iOS depois) |
| Escopo MVP | **Feed + Reels apenas** — 100% sem login, sem contas-robô |
| Extração | **Backend próprio com `yt-dlp`** + cache + proxy |
| Stories | **Fase 2** (exige sessão autenticada / contas-robô — fora do MVP) |

## Por que NÃO fazer a extração no app

- Instagram bloqueia IP de datacenter na 1ª request e faz TLS fingerprinting.
- O `doc_id` do GraphQL muda a cada 2–4 semanas → embutido no app = quebra a cada update.
- Centralizar no backend permite **cache** (maioria dos downloads nem toca o Instagram) e **rotação de proxy**.

## Arquitetura

```
┌────────────────┐     POST /resolve {url}      ┌──────────────────────┐
│  Flutter app   │ ───────────────────────────► │  Backend (FastAPI)   │
│                │ ◄─────────────────────────── │  + yt-dlp            │
│ - clipboard    │   {type, author, thumb,      │  + cache (shortcode) │
│ - share intent │    medias:[{quality,url}]}   │  + proxy residencial │
│ - preview      │                              └──────────┬───────────┘
│ - download→gal │     GET /download?id=...                │ yt-dlp -J <url>
└────────────────┘   (proxy-stream opcional)               ▼
                                                  Instagram GraphQL/CDN
```

---

## Backend (FastAPI + yt-dlp)

**Stack:** Python 3.12, FastAPI, `yt-dlp` (Python API `YoutubeDL`), `httpx`, cache (SQLite/Redis).
Deploy em container (Railway/Fly/VPS) — **não** roda em Supabase Edge Function (precisa de runtime Python + binário).

### Endpoints
- `POST /resolve` — body `{ "url": "https://www.instagram.com/reel/XXXX/" }`
  - Valida que é URL do Instagram (`/p/`, `/reel/`, `/tv/`).
  - Extrai shortcode → consulta cache → se miss, roda yt-dlp.
  - Retorna:
    ```json
    {
      "type": "reel",
      "author": "username",
      "thumbnail": "https://...",
      "title": "...",
      "medias": [
        { "quality": "1080p", "ext": "mp4", "url": "https://...cdninstagram...", "filesize": 1234567 }
      ]
    }
    ```
- `GET /download?token=...` — **proxy-stream opcional** da mídia (resolve URLs do CDN que expiram / questões de CORS no cliente). MVP pode devolver a URL direta do CDN; adicionar proxy se houver falhas.
- `GET /health` — healthcheck.

### Detalhes técnicos
- **Cache por shortcode** com TTL (ex.: 6h para reels, 1h para feed). Reduz drasticamente requests ao IG.
- **Proxy residencial** configurável via env (`HTTP_PROXY`/lista rotativa). Sem isso, escala mal.
- **yt-dlp options:** passar `proxy`, `quiet`, `noplaylist`; tratar `DownloadError` → mapear para erros de API (404 indisponível, 429 rate-limit, 403 privado).
- **Rate limiting** por IP do cliente (slowapi) para não queimar o backend.
- **Tratamento de erros** claro: conteúdo privado, removido, rate-limit, URL inválida.
- Manter `yt-dlp` **atualizado** (é o que absorve as mudanças do Instagram) — pin + update automatizado.

---

## App Flutter

**Stack:** Flutter estável, Riverpod (estado), `dio` (HTTP + progresso), `gal` (salvar na galeria), `receive_sharing_intent` (share sheet), clipboard nativo.

### Telas
1. **Home** — campo de URL + botão **Colar**, detecção automática de link do IG na área de transferência, lista de "recentes".
2. **Preview** — thumbnail, autor, seletor de qualidade, botão **Baixar** com barra de progresso.
3. **Downloads/Galeria** — itens baixados, abrir/compartilhar.

### Captura do link (2 caminhos, share intent é o melhor)
- **Share sheet (recomendado):** `receive_sharing_intent` — usuário toca "Compartilhar → OneSaver" dentro do Instagram. UX superior, sem restrição de clipboard.
- **Clipboard ao focar:** `WidgetsBindingObserver` + `AppLifecycleState.resumed` + `Clipboard.getData('text/plain')`.
  - ⚠️ Android 10+: só lê com app em foco. Android 12+/13+ mostra aviso de privacidade ao ler clipboard. Por isso preferir botão "Colar" explícito + share intent.

### Download
- `dio` com `onReceiveProgress` → arquivo temporário → `gal` salva em Movies/galeria.
- Permissões: Android 13+ usa `READ_MEDIA_VIDEO`; tratar fluxo de permissão.

---

## Fases / Milestones

- [ ] **F0 — Setup:** repo, estrutura `/backend` e `/app`, README, `.gitignore`.
- [ ] **F1 — Backend MVP:** `POST /resolve` com yt-dlp resolvendo reel/feed público; testar com `curl`. Sem cache/proxy ainda.
- [ ] **F2 — App MVP:** Flutter com colar URL manual → chama `/resolve` → preview → baixa na galeria.
- [ ] **F3 — Captura automática:** share intent + leitura de clipboard ao focar, com detecção de URL do IG.
- [ ] **F4 — Robustez:** cache por shortcode, suporte a proxy residencial, rate limiting, tratamento de erros, deploy do backend.
- [ ] **F5 — Polimento:** histórico, configurações, estados de erro/vazio, ícone, splash.
- [ ] **F6 (futuro) — Stories:** decisão sobre contas-robô vs API de terceiros, com avisos de ToS/risco.

---

## Riscos e conformidade

- **ToS da Meta:** baixar conteúdo de terceiros pode violar os Termos do Instagram e direitos autorais. Posicionar como ferramenta para conteúdo público / uso pessoal. Stories exigem conta autenticada (risco de ban) → fora do MVP.
- **Fragilidade:** Instagram muda endpoints/`doc_id` periodicamente. Mitigação: manter `yt-dlp` atualizado e isolar a extração no backend.
- **Proxy/custo:** sem proxy residencial o backend é bloqueado em escala. Orçar isso.
- **Licenças:** `yt-dlp` (Unlicense, permissiva) ✔. Evitar copiar de cobalt (AGPL-3.0) / gallery-dl (GPL-2.0) se o produto for fechado.

## Referências (bases de código)
- Extração: [yt-dlp](https://github.com/yt-dlp/yt-dlp) · [instagram.py extractor](https://github.com/yt-dlp/yt-dlp/blob/master/yt_dlp/extractor/instagram.py)
- Backend+API web exemplo: [riad-azz/instagram-video-downloader](https://github.com/riad-azz/instagram-video-downloader)
- App Flutter exemplos: [ravindravala/Flutter-Reels-downloader-for-instagram](https://github.com/ravindravala/Flutter-Reels-downloader-for-instagram) · [devyuji/isave_flutter](https://github.com/devyuji/isave_flutter)
