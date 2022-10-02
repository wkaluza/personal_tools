ARG IMAGE="nginx:1.21.6-alpine"
FROM $IMAGE

ARG HOST_TIMEZONE="Etc/UTC"
ENV TZ=$HOST_TIMEZONE

COPY "./" "/docker/"
HEALTHCHECK CMD ["/bin/sh", "/docker/healthcheck.sh"]

RUN ["/bin/sh", "/docker/configure_container.sh"]
