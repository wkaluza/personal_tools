FROM nginx:1.20.2

COPY ./healthcheck.sh /docker/

HEALTHCHECK CMD ["/bin/sh", "/docker/healthcheck.sh"]
