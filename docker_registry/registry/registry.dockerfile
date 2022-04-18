ARG IMAGE="registry:2.8.1"
FROM $IMAGE

COPY ./healthcheck.sh /docker/

HEALTHCHECK CMD ["/bin/sh", "/docker/healthcheck.sh"]
