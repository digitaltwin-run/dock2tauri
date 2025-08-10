# Dock2Tauri default Dockerfile
# Serves the local ./app folder using nginx

FROM nginx:alpine

# Remove default nginx static site
RUN rm -rf /usr/share/nginx/html/*

# Copy your built frontend (./app) into nginx public dir
COPY app /usr/share/nginx/html

# Expose container web port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
