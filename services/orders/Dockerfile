ARG BASE_IMAGE="public.ecr.aws/docker/library/node:20-alpine"
FROM ${BASE_IMAGE} AS base
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev && npm cache clean --force

COPY src ./src

ENV NODE_ENV=production \
    PORT=3000

USER node
EXPOSE 3000
CMD ["node", "src/index.js"]

