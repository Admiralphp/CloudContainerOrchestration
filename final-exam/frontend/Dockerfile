# Multi-stage build pour React Frontend
FROM node:18-alpine AS builder

WORKDIR /app

# Copier package.json et installer les dépendances
COPY package*.json ./
RUN npm install --production

# Copier le code source et builder
COPY . .
RUN npm run build

# Stage 2: Production avec Nginx
FROM nginx:1.25-alpine

# Copier la configuration Nginx personnalisée
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copier les fichiers buildés depuis le stage builder
COPY --from=builder /app/build /usr/share/nginx/html

# Exposer le port 80
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
