"""Modelos de entrada/saída da API."""

from pydantic import BaseModel, Field


class ResolveRequest(BaseModel):
    url: str = Field(..., description="URL de um post/reel/tv público do Instagram.")


class MediaItem(BaseModel):
    quality: str = Field(..., description="Rótulo de qualidade, ex.: '1080p' ou 'audio'.")
    ext: str = Field(..., description="Extensão/contêiner do arquivo, ex.: 'mp4'.")
    url: str = Field(..., description="URL direta da mídia no CDN do Instagram.")
    width: int | None = None
    height: int | None = None
    filesize: int | None = Field(None, description="Tamanho em bytes, quando conhecido.")
    has_audio: bool = True


class ResolveResponse(BaseModel):
    type: str = Field(..., description="'reel', 'post', 'tv' ou 'unknown'.")
    shortcode: str
    author: str | None = None
    title: str | None = None
    thumbnail: str | None = None
    medias: list[MediaItem]


class ErrorResponse(BaseModel):
    error: str
    detail: str | None = None
