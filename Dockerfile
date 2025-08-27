# Etapa de build
FROM python:3.11-bullseye as builder

# Instalar dependências de compilação
RUN apt-get update && apt-get install -y \
    gcc g++ python3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Etapa final
FROM python:3.11-bullseye

# Dependências necessárias para OpenCV/YOLO
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar dependências do builder
COPY --from=builder /root/.local /home/appuser/.local

# Criar usuário não-root
RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

ENV PATH="/home/appuser/.local/bin:$PATH"

# Copiar código
COPY --chown=appuser:appuser . .

# Expor porta
EXPOSE 8000

# Healthcheck simples
HEALTHCHECK CMD curl --fail http://localhost:8000/health || exit 1

# Rodar com Gunicorn
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
