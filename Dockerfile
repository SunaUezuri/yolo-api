# Use Python 3.11 slim como base
FROM python:3.11-slim

# Definir variáveis de ambiente
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV DEBIAN_FRONTEND=noninteractive

# Instalar dependências do sistema
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
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Criar usuário não-root
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Criar diretórios necessários
RUN mkdir -p /app/uploads /app/models && chown -R appuser:appuser /app

# Definir diretório de trabalho
WORKDIR /app

# Copiar requirements primeiro para aproveitar cache do Docker
COPY requirements.txt .

# Instalar dependências Python
RUN pip install --no-cache-dir -r requirements.txt

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

# Expor porta
EXPOSE 8000

# Health check simples
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD python -c "print('OK')" || exit 1

# Comando para executar a aplicação
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8000"]
