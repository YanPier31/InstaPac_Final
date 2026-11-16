# Usar una imagen de Python ligera
FROM python:3.10-slim

# Definir el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar el archivo de dependencias e instalarlas
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiar el resto del código del backend
COPY . .

# Exponer el puerto 8080 para la comunicación con el Frontend
EXPOSE 8080

# Comando para iniciar el servidor temporal
CMD ["python", "main.py"]