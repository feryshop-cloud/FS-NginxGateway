FROM nginx:1.27-alpine

RUN mkdir -p /etc/nginx/ssl /var/log/nginx /templates /etc/nginx/conf.d

RUN apk add --no-cache gettext

COPY nginx.conf /etc/nginx/nginx.conf
COPY templates/ /templates/
COPY html/ /usr/share/nginx/html/

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/docker-entrypoint.sh"]
