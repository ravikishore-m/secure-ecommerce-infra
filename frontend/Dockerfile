ARG NODE_BASE_IMAGE="public.ecr.aws/docker/library/node:20-alpine"
ARG NGINX_BASE_IMAGE="public.ecr.aws/nginx/nginx:1.27-alpine"
FROM ${NODE_BASE_IMAGE} AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install && npm cache clean --force
COPY . .
RUN npm run build
FROM ${NGINX_BASE_IMAGE}
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

