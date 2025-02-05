# syntax=docker/dockerfile:1

FROM nginx:latest
COPY init.sh /init.sh
RUN chmod +x /init.sh

CMD ["/init.sh"]
