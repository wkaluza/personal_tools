curl \
  --fail \
  --output /dev/null \
  --show-error \
  --silent \
  "http://localhost:3000/healthcheck" ||
  exit 1
