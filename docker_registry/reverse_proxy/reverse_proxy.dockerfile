FROM nginx:1.20.2

HEALTHCHECK \
--interval=10s \
--retries=10 \
--start-period=60s \
--timeout=5s \
CMD curl -s http://localhost:8080/_nginx_healthcheck | grep "HEALTHY" \
|| \
exit 1
