curl --silent "http://localhost:8080/_/nginx_healthcheck" |
  grep "HEALTHY" ||
  exit 1
