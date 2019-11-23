FROM python:3.7-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt --no-cache-dir

COPY main.py .

ENTRYPOINT [ "gunicorn", "--log-level=debug", "--bind=0.0.0.0:80", "--keep-alive=10", "--workers=4", "--worker-class=gevent", "main:app"]