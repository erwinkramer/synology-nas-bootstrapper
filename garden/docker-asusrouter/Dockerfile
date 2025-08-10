FROM python:3-slim

# Install tools from PyPI
RUN pip install --no-cache-dir asusrouter aiohttp apscheduler

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
