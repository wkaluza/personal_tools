ARG IMAGE="gogs/gogs:0.12.6"
FROM $IMAGE

COPY ./healthcheck.sh /docker/
HEALTHCHECK CMD ["/bin/sh", "/docker/healthcheck.sh"]
