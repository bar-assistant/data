FROM node:20-alpine

RUN mkdir -p /data

WORKDIR /data

COPY . .

RUN npm install

RUN npm run build

VOLUME [ "/data" ]
