FROM python:3.11-slim
# libgl1 + libglib2.0-0: MediaPipe pulls opencv-contrib-python, which loads them on import.
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app app
COPY scripts scripts
ENV PYTHONUNBUFFERED=1
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}
