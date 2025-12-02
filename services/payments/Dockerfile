FROM node:20-alpine AS base
WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev && npm cache clean --force

COPY src ./src

ENV NODE_ENV=production \
    PORT=3000

USER node
EXPOSE 3000
CMD ["node", "src/index.js"]

