set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function ssh_keyscan
{
  local host="$1"

  quiet_stderr ssh-keyscan \
    -H \
    -t "ecdsa,ed25519,rsa" \
    "${host}"
}

function add_ssh_known_host
{
  local host="$1"

  local known_hosts="${HOME}/.ssh/known_hosts"

  ssh_keyscan "${host}" >>"${known_hosts}"
}

function remove_ssh_known_host
{
  local host="$1"

  local known_hosts="${HOME}/.ssh/known_hosts"

  quiet ssh-keygen \
    -f "${known_hosts}" \
    -R "${host}" || true
}

function refresh_ssh_known_host
{
  local host="$1"

  local known_hosts="${HOME}/.ssh/known_hosts"

  remove_ssh_known_host \
    "${host}"
  add_ssh_known_host \
    "${host}"
}

function generate_rsa4096_key_pair
{
  local output_dir
  output_dir="$(mktemp -d)"

  local secret_key_file="${output_dir}/key"
  local public_key_file="${secret_key_file}.pub"

  pushd "${output_dir}" &>/dev/null
  ssh-keygen \
    -t rsa \
    -b 4096 \
    -C "" \
    -f "${secret_key_file}" \
    -P "" &>/dev/null
  popd &>/dev/null

  local secret_key
  secret_key="$(cat "${secret_key_file}" | base64 -w0)"
  local public_key
  public_key="$(cat "${public_key_file}" | base64 -w0)"

  echo "{\"secret_key\":\"${secret_key}\",\"public_key\":\"${public_key}\"}" |
    jq --compact-output --sort-keys '.' -

  rm -rf "${output_dir}" &>/dev/null
}
