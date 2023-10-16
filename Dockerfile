FROM node:20-alpine

RUN mkdir -p /data

VOLUME [ "/data" ]

RUN npm install -g sharp sharp-cli

WORKDIR /data
