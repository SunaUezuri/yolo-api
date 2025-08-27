# Use Python 3.11 slim como base (mais estável para ML)
FROM python:3.11-slim as builder

# Instalar dependências do sistema necessárias para build
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libgthread-2.0-0 \
    libgtk-3-0 \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libatlas-base-dev \
    libhdf5-dev \
    libhdf5-serial-dev \
    libhdf5-103 \
    libqtgui4 \
    libqtwebkit4 \
    libqt4-test \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Criar usuário não-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Criar diretório de trabalho
WORKDIR /app

# Copiar requirements primeiro para aproveitar cache do Docker
COPY requirements.txt .

# Instalar dependências Python
RUN pip install --no-cache-dir --user -r requirements.txt

# Segunda etapa: imagem final otimizada
FROM python:3.11-slim

# Instalar apenas runtime dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgomp1 \
    libgthread-2.0-0 \
    libgtk-3-0 \
    libavcodec58 \
    libavformat58 \
    libswscale5 \
    libv4l-0 \
    libxvidcore4 \
    libx264-163 \
    libjpeg62-turbo \
    libpng16-16 \
    libtiff5 \
    libatlas-base-dev \
    libhdf5-103 \
    libqtgui4 \
    libqtwebkit4 \
    libqt4-test \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Criar usuário não-root (mesmo UID/GID)
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Criar diretórios necessários
RUN mkdir -p /app/uploads /app/models && chown -R appuser:appuser /app

# Definir diretório de trabalho
WORKDIR /app

# Copiar Python packages do builder
COPY --from=builder /root/.local /home/appuser/.local

# Copiar código da aplicação
COPY --chown=appuser:appuser . .

# Baixar modelo YOLO se não existir
RUN python -c "from ultralytics import YOLO; YOLO('yolov8n.pt')" || true

# Definir permissões corretas
RUN chown -R appuser:appuser /app && \
    chmod -R 755 /app && \
    chmod 777 /app/uploads

# Mudar para usuário não-root
USER appuser

# Adicionar .local/bin ao PATH
ENV PATH="/home/appuser/.local/bin:$PATH"

# Expor porta
EXPOSE 8000

# Variáveis de ambiente para otimização
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV OMP_NUM_THREADS=1
ENV MKL_NUM_THREADS=1

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Comando para executar a aplicação
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8000"]
