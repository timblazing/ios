FROM python:3.12-slim
# The server only needs Pillow; omit pip and its vendored packages at runtime.
RUN pip install --no-cache-dir pillow==13.0.0 \
    && pip uninstall --yes pip
WORKDIR /app
COPY gateway.py .
ENV PYTHONUNBUFFERED=1 CACHE_DIR=/cache
EXPOSE 9292
CMD ["python", "gateway.py"]
