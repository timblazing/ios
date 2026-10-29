FROM python:3.12-slim
RUN pip install --no-cache-dir pillow==11.3.0
WORKDIR /app
COPY gateway.py .
ENV PYTHONUNBUFFERED=1 CACHE_DIR=/cache
EXPOSE 9292
CMD ["python", "gateway.py"]
