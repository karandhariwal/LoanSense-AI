"""
app/services/cache_service.py

Redis-backed cache service for LoanSense AI.

Cache layers (in order of speed):
  1. chat:{loan_id}:{query_hash}   → full ChatResponse JSON        TTL 3600s (1 h)
  2. docs:{loan_id}:{query_hash}   → serialised ChromaDB chunks    TTL 1800s (30 min)
  3. analysis:{loan_id}            → analysis_json from LoanReport TTL 86400s (24 h)

All values are stored as UTF-8 JSON strings.  Missing keys return None so callers
can treat a cache miss exactly like a DB miss.
"""

import hashlib
import json
import logging
from typing import Any, Optional

import redis.asyncio as aioredis

from app.core.config import settings

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# TTLs (seconds)
# ---------------------------------------------------------------------------
_TTL_CHAT   = 3600   # 1 hour  – LLM response for a (loan, query) pair
_TTL_DOCS   = 1800   # 30 min  – retrieved ChromaDB chunks
_TTL_ANALYSIS = 86400  # 24 hours – persisted analysis JSON


def _query_hash(text: str) -> str:
    """Stable, short hash used as part of cache keys."""
    normalised = " ".join(text.lower().split())   # collapse whitespace, lowercase
    return hashlib.sha256(normalised.encode()).hexdigest()[:24]


class RedisCacheService:
    """
    Async Redis cache wrapper.

    Usage (inside an async function):
        cached = await cache.get_chat(loan_id, query)
        if cached:
            return ChatResponse(**cached)
        ...
        await cache.set_chat(loan_id, query, response.model_dump())
    """

    def __init__(self) -> None:
        self._client: Optional[aioredis.Redis] = None

    async def _get_client(self) -> aioredis.Redis:
        """Return (and lazily create) the shared async Redis client."""
        if self._client is None:
            self._client = aioredis.from_url(
                settings.REDIS_URL,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2,
            )
        return self._client

    # ── Low-level helpers ────────────────────────────────────────────────────

    async def _get(self, key: str) -> Optional[Any]:
        try:
            client = await self._get_client()
            raw = await client.get(key)
            if raw is None:
                return None
            return json.loads(raw)
        except Exception as exc:
            logger.warning(f"[Cache] GET failed for key={key}: {exc}")
            return None

    async def _set(self, key: str, value: Any, ttl: int) -> None:
        try:
            client = await self._get_client()
            await client.setex(key, ttl, json.dumps(value, default=str))
        except Exception as exc:
            logger.warning(f"[Cache] SET failed for key={key}: {exc}")

    async def delete_loan(self, loan_id: str) -> None:
        """Invalidate all cache entries for a given loan (e.g. after re-upload)."""
        try:
            client = await self._get_client()
            pattern = f"*:{loan_id}:*"
            cursor = 0
            deleted = 0
            while True:
                cursor, keys = await client.scan(cursor, match=pattern, count=100)
                if keys:
                    await client.delete(*keys)
                    deleted += len(keys)
                if cursor == 0:
                    break
            # Also clear analysis key
            await client.delete(f"analysis:{loan_id}")
            logger.info(f"[Cache] Invalidated {deleted + 1} keys for loan_id={loan_id}")
        except Exception as exc:
            logger.warning(f"[Cache] delete_loan failed for loan_id={loan_id}: {exc}")

    # ── Chat response cache ──────────────────────────────────────────────────

    def _chat_key(self, loan_id: str, query: str) -> str:
        return f"chat:{loan_id}:{_query_hash(query)}"

    async def get_chat(self, loan_id: str, query: str) -> Optional[dict]:
        """Return cached ChatResponse dict, or None on miss."""
        data = await self._get(self._chat_key(loan_id, query))
        if data:
            logger.info(f"[Cache] HIT  chat:{loan_id} query='{query[:60]}'")
        return data

    async def set_chat(self, loan_id: str, query: str, response_dict: dict) -> None:
        """Store a ChatResponse dict in Redis."""
        await self._set(self._chat_key(loan_id, query), response_dict, _TTL_CHAT)
        logger.info(f"[Cache] SET  chat:{loan_id} query='{query[:60]}' ttl={_TTL_CHAT}s")

    # ── Document chunk cache ─────────────────────────────────────────────────

    def _docs_key(self, loan_id: str, query: str) -> str:
        return f"docs:{loan_id}:{_query_hash(query)}"

    async def get_docs(self, loan_id: str, query: str) -> Optional[list]:
        """Return cached list of {page_content, metadata} dicts, or None."""
        data = await self._get(self._docs_key(loan_id, query))
        if data:
            logger.info(f"[Cache] HIT  docs:{loan_id} query='{query[:60]}'")
        return data

    async def set_docs(self, loan_id: str, query: str, docs: list) -> None:
        """Serialise and store retrieved document chunks."""
        serialisable = [
            {"page_content": d.page_content, "metadata": d.metadata}
            for d in docs
        ]
        await self._set(self._docs_key(loan_id, query), serialisable, _TTL_DOCS)
        logger.info(f"[Cache] SET  docs:{loan_id} query='{query[:60]}' chunks={len(docs)} ttl={_TTL_DOCS}s")

    # ── Analysis JSON cache ──────────────────────────────────────────────────

    def _analysis_key(self, loan_id: str) -> str:
        return f"analysis:{loan_id}"

    async def get_analysis(self, loan_id: str) -> Optional[dict]:
        """Return cached analysis_json dict, or None."""
        data = await self._get(self._analysis_key(loan_id))
        if data:
            logger.info(f"[Cache] HIT  analysis:{loan_id}")
        return data

    async def set_analysis(self, loan_id: str, analysis_json: dict) -> None:
        """Cache the raw analysis_json payload from the LoanReport row."""
        await self._set(self._analysis_key(loan_id), analysis_json, _TTL_ANALYSIS)
        logger.info(f"[Cache] SET  analysis:{loan_id} ttl={_TTL_ANALYSIS}s")

    async def close(self) -> None:
        if self._client is not None:
            await self._client.aclose()
            self._client = None


# ---------------------------------------------------------------------------
# Global singleton – import and use directly
# ---------------------------------------------------------------------------
cache = RedisCacheService()
