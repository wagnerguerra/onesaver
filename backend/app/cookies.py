"""Pool de cookies de contas-robô, com rotação round-robin e cooldown.

Carrega um arquivo único (`cookies_file`) e/ou todos os `*.txt` de `cookies_dir`.
Quando um cookie falha (auth_required/rate-limit), entra em "cooldown" e é pulado
por um tempo, dando chance aos outros. Sem nenhum cookie, opera em modo anônimo.
"""

import glob
import os
import threading
import time


class CookiePool:
    def __init__(self, cookies_file: str, cookies_dir: str, cooldown: int) -> None:
        self._cooldown = cooldown
        self._lock = threading.Lock()
        self._idx = 0
        self._cooldown_until: dict[str, float] = {}
        self._cookies_file = cookies_file
        self._cookies_dir = cookies_dir
        self._paths: list[str] = self._discover()

    def _discover(self) -> list[str]:
        paths: list[str] = []
        if self._cookies_file and os.path.isfile(self._cookies_file):
            paths.append(self._cookies_file)
        if self._cookies_dir and os.path.isdir(self._cookies_dir):
            for p in sorted(glob.glob(os.path.join(self._cookies_dir, "*.txt"))):
                if os.path.isfile(p) and p not in paths:
                    paths.append(p)
        return paths

    def reload(self) -> None:
        """Re-descobre os arquivos em disco (ex.: após adicionar/rotacionar contas)."""
        with self._lock:
            self._paths = self._discover()
            # Limpa cooldowns de arquivos que não existem mais.
            self._cooldown_until = {
                k: v for k, v in self._cooldown_until.items() if k in self._paths
            }

    def size(self) -> int:
        return len(self._paths)

    def available(self) -> int:
        now = time.monotonic()
        with self._lock:
            return sum(1 for p in self._paths if self._cooldown_until.get(p, 0) <= now)

    def acquire(self) -> str | None:
        """Retorna o próximo cookie saudável (round-robin), ou None se não houver
        nenhum configurado / todos em cooldown (caller pode tentar anônimo)."""
        now = time.monotonic()
        with self._lock:
            n = len(self._paths)
            if n == 0:
                return None
            for _ in range(n):
                path = self._paths[self._idx % n]
                self._idx += 1
                if self._cooldown_until.get(path, 0) <= now:
                    return path
            return None  # todos em cooldown

    def report_failure(self, path: str) -> None:
        with self._lock:
            self._cooldown_until[path] = time.monotonic() + self._cooldown

    def report_success(self, path: str) -> None:
        with self._lock:
            self._cooldown_until.pop(path, None)

    def status(self) -> dict:
        return {
            "total": self.size(),
            "available": self.available(),
            "cooling_down": self.size() - self.available(),
        }
