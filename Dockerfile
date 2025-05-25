FROM python:3.10-slim

# Crea directorio de trabajo
WORKDIR /app

# Copia el archivo de dependencias y lo instala
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia todo lo necesario del backend
COPY backend/ /app/backend

# Comando para iniciar el backend FastAPI
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8080"]
