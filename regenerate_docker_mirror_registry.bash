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
    "gitlab/gitlab-ce" \
    "14.9.3-ce.0"
  prefetch_base_image \
    "mongo" \
    "5.0.7"
  prefetch_base_image \
    "neo4j" \
    "4.4.5"
  prefetch_base_image \
    "nginx" \
    "1.21.6-alpine"
  prefetch_base_image \
    "postgres" \
    "14.2"
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

function list_local_docker_tags
{
  docker image ls --format '{{ .Repository }}:{{ .Tag }}' |
    grep -v '<none>' |
    sort |
    uniq
}

function untag_local_images
{
  for img in $(list_local_docker_tags); do
    docker image rm \
      --force \
      --no-prune \
      "${img}"
  done
}

function main
{
  populate_local_registry
  untag_local_images
}

main
