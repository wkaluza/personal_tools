curl --silent "http://localhost:8080/_nginx_healthcheck" |
  grep "HEALTHY" ||
  exit 1
