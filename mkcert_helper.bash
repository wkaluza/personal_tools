set -euo pipefail
shopt -s inherit_errexit

function generate_cert
{
  local domain="$1"

  mkcert \
    -cert-file "${domain}.pem" \
    -key-file "${domain}-key.pem" \
    "${domain}"
}

function main
{
  local certs_dir="${HOME}/.certificates___"

  mkcert -install

  mkdir --parents "${certs_dir}"

  pushd "${certs_dir}" >/dev/null
  generate_cert "docker.registry.local"
  generate_cert "docker.registry.mirror"
  generate_cert "main.localhost"
  popd >/dev/null
}

main
