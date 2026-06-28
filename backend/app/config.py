"""Configuração do backend OneSaver, carregada de variáveis de ambiente / .env."""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="ONESAVER_", extra="ignore")

    # --- Proxy ---
    # Proxy único (compat). Ex.: "http://user:pass@host:port". Vazio = sem proxy.
    proxy: str = ""
    # Lista de proxies para rotação (separados por vírgula). Tem prioridade sobre `proxy`.
    proxies: str = ""

    # --- Cookies (conta-robô) ---
    # Arquivo único de cookies (formato Netscape). Compat com a Fase 1.
    cookies_file: str = ""
    # Diretório com vários cookies "*.txt" para o pool (rotação). Ex.: /secrets/cookies
    cookies_dir: str = ""
    # Tempo (s) que um cookie fica "de molho" após falhar (auth/rate-limit).
    cookie_cooldown: int = 600

    # --- Cache ---
    # TTL do cache de resolução, em segundos (padrão 6h).
    cache_ttl: int = 6 * 60 * 60
    # Máximo de entradas no cache em memória (evita crescimento ilimitado).
    cache_max_entries: int = 5000

    # --- Segurança / limites ---
    # Se definido, exige o header "X-API-Key" com este valor em /resolve.
    api_key: str = ""
    # Limite de requisições por IP no /resolve.
    rate_limit: str = "30/minute"
    # Origens permitidas no CORS. "*" libera geral (ok para dev).
    cors_origins: str = "*"

    def proxy_list(self) -> list[str]:
        if self.proxies.strip():
            return [p.strip() for p in self.proxies.split(",") if p.strip()]
        if self.proxy.strip():
            return [self.proxy.strip()]
        return []


settings = Settings()
