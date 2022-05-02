set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
cd "${THIS_SCRIPT_DIR}"

function prefetch_base_image
{
  local collection="$1"
  local image="$2"
  local tag="$3"

  docker pull "${collection}/${image}:${tag}"
}

function populate_operating_systems
{
  prefetch_base_image \
    "library" \
    "alpine" \
    "3.15.4"

  prefetch_base_image \
    "library" \
    "debian" \
    "10.12"
  prefetch_base_image \
    "library" \
    "debian" \
    "10.12-slim"
  prefetch_base_image \
    "library" \
    "debian" \
    "buster"
  prefetch_base_image \
    "library" \
    "debian" \
    "buster-slim"
  prefetch_base_image \
    "library" \
    "debian" \
    "11.3"
  prefetch_base_image \
    "library" \
    "debian" \
    "11.3-slim"
  prefetch_base_image \
    "library" \
    "debian" \
    "bullseye"
  prefetch_base_image \
    "library" \
    "debian" \
    "bullseye-slim"

  prefetch_base_image \
    "library" \
    "ubuntu" \
    "20.04"
  prefetch_base_image \
    "library" \
    "ubuntu" \
    "22.04"
}

function prefetch_servers
{
  prefetch_base_image \
    "library" \
    "caddy" \
    "2.5.0"
  prefetch_base_image \
    "library" \
    "caddy" \
    "2.5.0-builder"
  prefetch_base_image \
    "library" \
    "caddy" \
    "2.5.0-alpine"
  prefetch_base_image \
    "library" \
    "caddy" \
    "2.5.0-builder-alpine"

  prefetch_base_image \
    "library" \
    "httpd" \
    "2.4.53"
  prefetch_base_image \
    "library" \
    "httpd" \
    "2.4.53-alpine3.15"

  prefetch_base_image \
    "library" \
    "nginx" \
    "1.21.6"
  prefetch_base_image \
    "library" \
    "nginx" \
    "1.21.6-perl"
  prefetch_base_image \
    "library" \
    "nginx" \
    "1.21.6-alpine"
  prefetch_base_image \
    "library" \
    "nginx" \
    "1.21.6-alpine-perl"
}

function prefetch_databases
{
  prefetch_base_image \
    "library" \
    "cassandra" \
    "4.0.3"

  prefetch_base_image \
    "clickhouse" \
    "clickhouse-server" \
    "22.4.4.7-alpine"
  prefetch_base_image \
    "clickhouse" \
    "clickhouse-server" \
    "22.4.4.7"

  prefetch_base_image \
    "cockroachdb" \
    "cockroach" \
    "v21.2.9"

  prefetch_base_image \
    "library" \
    "couchdb" \
    "3.2.2"

  prefetch_base_image \
    "library" \
    "elasticsearch" \
    "8.1.3"

  prefetch_base_image \
    "library" \
    "mariadb" \
    "10.7.3"

  prefetch_base_image \
    "library" \
    "mongo" \
    "5.0.7"

  prefetch_base_image \
    "library" \
    "mysql" \
    "8.0.29"
  prefetch_base_image \
    "library" \
    "mysql" \
    "8.0.29-oracle"

  prefetch_base_image \
    "library" \
    "neo4j" \
    "4.4.6"

  prefetch_base_image \
    "library" \
    "postgres" \
    "14.2"
  prefetch_base_image \
    "library" \
    "postgres" \
    "14.2-alpine3.15"

  prefetch_base_image \
    "library" \
    "rabbitmq" \
    "3.9.16-management-alpine"
  prefetch_base_image \
    "library" \
    "rabbitmq" \
    "3.9.16-management"
  prefetch_base_image \
    "library" \
    "rabbitmq" \
    "3.9.16-alpine"
  prefetch_base_image \
    "library" \
    "rabbitmq" \
    "3.9.16"

  prefetch_base_image \
    "library" \
    "redis" \
    "7.0.0-alpine3.15"
  prefetch_base_image \
    "library" \
    "redis" \
    "7.0.0"

  prefetch_base_image \
    "library" \
    "rethinkdb" \
    "2.4.1"

  prefetch_base_image \
    "library" \
    "solr" \
    "6.6.6"
  prefetch_base_image \
    "library" \
    "solr" \
    "6.6.6-slim"
}

function prefetch_git_frontends
{
  prefetch_base_image \
    "gitbucket" \
    "gitbucket" \
    "4.37.2"

  prefetch_base_image \
    "gitea" \
    "gitea" \
    "1.16.6"
  prefetch_base_image \
    "gitea" \
    "gitea" \
    "1.16.6-rootless"

  prefetch_base_image \
    "gitlab" \
    "gitlab-ce" \
    "14.10.0-ce.0"
  prefetch_base_image \
    "gitlab" \
    "gitlab-runner" \
    "alpine3.15-v14.10.0"
  prefetch_base_image \
    "gitlab" \
    "gitlab-runner" \
    "ubuntu-v14.10.0"

  prefetch_base_image \
    "gogs" \
    "gogs" \
    "0.12.6"
}

function prefetch_golang
{
  prefetch_base_image \
    "library" \
    "golang" \
    "1.18.1"
  prefetch_base_image \
    "library" \
    "golang" \
    "1.18.1-alpine3.15"
  prefetch_base_image \
    "library" \
    "golang" \
    "1.18.1-buster"
  prefetch_base_image \
    "library" \
    "golang" \
    "1.18.1-bullseye"
}

function prefetch_nodejs
{
  prefetch_base_image \
    "library" \
    "node" \
    "16.15.0"
  prefetch_base_image \
    "library" \
    "node" \
    "16.15.0-buster"
  prefetch_base_image \
    "library" \
    "node" \
    "16.15.0-bullseye"
  prefetch_base_image \
    "library" \
    "node" \
    "16.15.0-slim"
  prefetch_base_image \
    "library" \
    "node" \
    "16.15.0-buster-slim"
  prefetch_base_image \
    "library" \
    "node" \
    "16.15.0-bullseye-slim"
  prefetch_base_image \
    "library" \
    "node" \
    "16.15.0-alpine3.15"
  prefetch_base_image \
    "library" \
    "node" \
    "18.0.0"
  prefetch_base_image \
    "library" \
    "node" \
    "18.0.0-buster"
  prefetch_base_image \
    "library" \
    "node" \
    "18.0.0-bullseye"
  prefetch_base_image \
    "library" \
    "node" \
    "18.0.0-slim"
  prefetch_base_image \
    "library" \
    "node" \
    "18.0.0-buster-slim"
  prefetch_base_image \
    "library" \
    "node" \
    "18.0.0-bullseye-slim"
  prefetch_base_image \
    "library" \
    "node" \
    "18.0.0-alpine3.15"
}

function prefetch_python
{
  prefetch_base_image \
    "library" \
    "python" \
    "3.10.4"
  prefetch_base_image \
    "library" \
    "python" \
    "3.10.4-slim"
  prefetch_base_image \
    "library" \
    "python" \
    "3.10.4-buster"
  prefetch_base_image \
    "library" \
    "python" \
    "3.10.4-slim-buster"
  prefetch_base_image \
    "library" \
    "python" \
    "3.10.4-bullseye"
  prefetch_base_image \
    "library" \
    "python" \
    "3.10.4-slim-bullseye"
  prefetch_base_image \
    "library" \
    "python" \
    "3.10.4-alpine3.15"
}

function prefetch_rust
{
  prefetch_base_image \
    "library" \
    "rust" \
    "1.60.0"
  prefetch_base_image \
    "library" \
    "rust" \
    "1.60.0-slim"
  prefetch_base_image \
    "library" \
    "rust" \
    "1.60.0-buster"
  prefetch_base_image \
    "library" \
    "rust" \
    "1.60.0-slim-buster"
  prefetch_base_image \
    "library" \
    "rust" \
    "1.60.0-bullseye"
  prefetch_base_image \
    "library" \
    "rust" \
    "1.60.0-slim-bullseye"
  prefetch_base_image \
    "library" \
    "rust" \
    "1.60.0-alpine3.15"
}

function prefetch_haskell
{
  prefetch_base_image \
    "library" \
    "haskell" \
    "9.2.2"
  prefetch_base_image \
    "library" \
    "haskell" \
    "9.2.2-slim"
  prefetch_base_image \
    "library" \
    "haskell" \
    "9.2.2-buster"
  prefetch_base_image \
    "library" \
    "haskell" \
    "9.2.2-slim-buster"
}

function main
{
  prefetch_base_image \
    "library" \
    "registry" \
    "2.8.1"

  populate_operating_systems
  prefetch_servers
  prefetch_databases
  prefetch_git_frontends
  prefetch_golang
  prefetch_nodejs
  prefetch_python
  prefetch_rust
  prefetch_haskell
}

main
