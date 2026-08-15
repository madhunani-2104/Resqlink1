# ResQ - Production Deployment Guide

This document covers containerizing and deploying the ResQ Central Cloud Backend and Flutter Web Client to cloud platforms (AWS, DigitalOcean, Docker, or Vercel/Render).

---

## 1. Dockerizing Backend

Create `backend/Dockerfile`:

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 5000

CMD ["node", "server.js"]
```

### Docker Compose Configuration (`docker-compose.yml`)

```yaml
version: '3.8'

services:
  mongodb:
    image: mongo:6.0
    container_name: resq_mongo
    restart: always
    ports:
      - "27017:27017"
    volumes:
      - mongo_data:/data/db

  backend:
    build: ./backend
    container_name: resq_backend
    restart: always
    ports:
      - "5000:5000"
    environment:
      - PORT=5000
      - NODE_ENV=production
      - MONGO_URI=mongodb://mongodb:27017/resq_db
      - JWT_SECRET=production_secret_key_change_me
    depends_on:
      - mongodb

volumes:
  mongo_data:
```

### Running with Docker Compose:
```bash
docker-compose up -d --build
```

---

## 2. Building & Hosting Flutter Web

1. Compile production web bundle:
   ```bash
   cd resq_app
   flutter build web --release
   ```

2. Output files will be generated in `resq_app/build/web/`.
3. Host on NGINX, Firebase Hosting, or Vercel.

### Sample NGINX Web Server Configuration:

```nginx
server {
    listen 80;
    server_name resq.disaster-response.org;

    location / {
        root /var/www/resq_app/build/web;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```
