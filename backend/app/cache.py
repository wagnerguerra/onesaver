"""Cache em memória com TTL e limite de tamanho.

MVP usa um dict em processo (por worker). Para multi-instância com cache
compartilhado, trocar por Redis mantendo a mesma interface get/set.
"""

import threading
import time
from collections import OrderedDict
from typing import Any


class TTLCache:
    def __init__(self, ttl_seconds: int, max_entries: int = 5000) -> None:
        self._ttl = ttl_seconds
        self._max = max_entries
        self._store: "OrderedDict[str, tuple[float, Any]]" = OrderedDict()
        self._lock = threading.Lock()

    def get(self, key: str) -> Any | None:
        now = time.monotonic()
        with self._lock:
            item = self._store.get(key)
            if item is None:
                return None
            expires_at, value = item
            if now >= expires_at:
                self._store.pop(key, None)
                return None
            # Marca como recém-usado (LRU).
            self._store.move_to_end(key)
            return value

    def set(self, key: str, value: Any) -> None:
        with self._lock:
            self._store[key] = (time.monotonic() + self._ttl, value)
            self._store.move_to_end(key)
            self._evict_locked()

    def _evict_locked(self) -> None:
        now = time.monotonic()
        # Remove expirados primeiro.
        expired = [k for k, (exp, _) in self._store.items() if exp <= now]
        for k in expired:
            self._store.pop(k, None)
        # Se ainda exceder o limite, descarta os mais antigos (LRU).
        while len(self._store) > self._max:
            self._store.popitem(last=False)
