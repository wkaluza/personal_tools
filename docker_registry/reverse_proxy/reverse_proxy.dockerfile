FROM nginx:1.20.2

COPY ./healthcheck.sh /docker/

HEALTHCHECK \
--interval=10s \
--retries=10 \
--start-period=60s \
--timeout=5s \
CMD ["/bin/sh", "/docker/healthcheck.sh"]
