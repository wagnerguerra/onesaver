# Sessão do backend via cookies (conta-robô)

O OneSaver não pede login do **usuário final**. Para destravar o conteúdo que o
Instagram passou a exigir sessão, o **backend** usa cookies de uma conta de serviço
("conta-robô"). Este guia mostra como gerar e instalar esses cookies com segurança.

> ⚠️ **Risco e responsabilidade**
> - Automatizar uma conta para baixar conteúdo **viola os Termos do Instagram/Meta**; a conta pode ser **banida/limitada**. Use uma conta **descartável**, nunca pessoal.
> - O arquivo de cookies dá **acesso total à conta**. Trate como senha: nunca versione, nunca compartilhe, restrinja o acesso ao servidor.
> - Combine com **proxy residencial** (`ONESAVER_PROXY`) em produção para reduzir bloqueio do IP do servidor.

## 1. Crie uma conta-robô descartável
Crie uma conta nova do Instagram só para isto (idealmente já "aquecida" por alguns dias).
**Você** faz isso — eu (assistente) não crio contas nem faço login.

## 2. Exporte os cookies no formato Netscape (`cookies.txt`)

**Opção A — extensão de navegador (mais simples):**
1. Faça login na conta-robô no navegador.
2. Instale uma extensão de exportação de cookies (ex.: "Get cookies.txt LOCALLY").
3. Com `instagram.com` aberto e logado, exporte → salve como `cookies.txt`.

**Opção B — via yt-dlp a partir do seu navegador:**
```bash
yt-dlp --cookies-from-browser chrome --cookies cookies.txt --simulate \
  "https://www.instagram.com/p/<shortcode>/"
```
Isso grava um `cookies.txt` reutilizável.

## 3. Instale no backend
Copie o arquivo para:
```
backend/secrets/cookies.txt
```
O `docker-compose.yml` já monta `./secrets` como `/secrets:ro` e aponta
`ONESAVER_COOKIES_FILE=/secrets/cookies.txt`. Sem o arquivo, o backend roda anônimo.

Suba/recarregue:
```bash
docker compose -f backend/docker-compose.yml up -d --build
```

## 4. Verifique
```bash
curl http://localhost:8000/health
# -> {"status":"ok","auth":{"cookies_configured":true,"cookies_file_present":true}}

curl -X POST http://localhost:8000/resolve \
  -H "Content-Type: application/json" \
  -d '{"url":"https://www.instagram.com/reel/<shortcode>/"}'
```
Com cookies válidos, o `/resolve` deve retornar as `medias` em vez de `403 auth_required`.

## Manutenção
- Cookies **expiram**; quando o `/resolve` voltar a dar `403 auth_required`, **reexporte**.
- Rotacione contas se a atual for limitada (checkpoint/ban).
- Para escala, mantenha um **pool de contas** e rotação de proxy (Fase 4).
