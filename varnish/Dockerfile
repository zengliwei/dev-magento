FROM varnish:latest

COPY default.vcl /etc/varnish/
COPY docker-bootstrap /usr/local/bin/

ENV BACKEND_HOST=127.0.0.1

CMD ["docker-bootstrap"]