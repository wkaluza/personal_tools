FROM registry:2.8.1

COPY ./healthcheck.sh /docker/

HEALTHCHECK CMD ["/bin/sh", "/docker/healthcheck.sh"]
