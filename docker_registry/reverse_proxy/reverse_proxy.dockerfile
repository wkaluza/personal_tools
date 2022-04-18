ARG IMAGE="nginx:1.21.6-alpine"
FROM $IMAGE

COPY ./healthcheck.sh /docker/

HEALTHCHECK CMD ["/bin/sh", "/docker/healthcheck.sh"]
