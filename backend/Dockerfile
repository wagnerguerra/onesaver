FROM python:3.12-slim

# ffmpeg ajuda o yt-dlp em alguns merges/containers de mídia.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8000

# 1 worker no MVP; escalar via réplicas atrás de um proxy depois.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
