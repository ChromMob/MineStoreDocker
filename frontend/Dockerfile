# syntax=docker/dockerfile:1

FROM node:20-alpine

RUN npm install -g pnpm

COPY init.sh /init.sh
RUN chmod +x /init.sh
CMD ["/init.sh"]