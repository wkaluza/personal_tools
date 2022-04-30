set -euo pipefail
shopt -s inherit_errexit

function prefetch_base_image
{
  local repository="$1"
  local tag="$2"

  docker pull "${repository}:${tag}"
  docker pull "${repository}:latest"
}

function populate_local_registry
{
  prefetch_base_image \
    "alpine" \
    "3.15.4"
  prefetch_base_image \
    "debian" \
    "11.3"
  prefetch_base_image \
    "debian" \
    "11.3-slim"
  prefetch_base_image \
    "gitlab/gitlab-ce" \
    "14.10.0-ce.0"
  prefetch_base_image \
    "gitlab/gitlab-runner" \
    "alpine-v14.10.0"
  prefetch_base_image \
    "gitlab/gitlab-runner" \
    "ubuntu-v14.10.0"
  prefetch_base_image \
    "mongo" \
    "5.0.7"
  prefetch_base_image \
    "neo4j" \
    "4.4.6"
  prefetch_base_image \
    "nginx" \
    "1.21.6-alpine"
  prefetch_base_image \
    "postgres" \
    "14.2"
  prefetch_base_image \
    "postgres" \
    "14.2-alpine"
  prefetch_base_image \
    "registry" \
    "2.8.1"
  prefetch_base_image \
    "ubuntu" \
    "20.04"
  prefetch_base_image \
    "ubuntu" \
    "22.04"
}

function main
{
  populate_local_registry
}

main
