FROM python:3-alpine

WORKDIR /app

# Copy requirements first so pip install runs before app files (for better caching)
COPY requirements.txt .

# Install tools from PyPI
RUN pip install --no-cache-dir -r requirements.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
