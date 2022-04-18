ARG IMAGE="nginx:1.20.2"
FROM $IMAGE

COPY ./healthcheck.sh /docker/

HEALTHCHECK CMD ["/bin/sh", "/docker/healthcheck.sh"]
