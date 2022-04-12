FROM registry:2.8.1

HEALTHCHECK \
--interval=10s \
--retries=10 \
--start-period=60s \
--timeout=5s \
CMD wget -q -O - http://localhost:5000/v2/_catalog | grep "repositories" \
|| \
exit 1
