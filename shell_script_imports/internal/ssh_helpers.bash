set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function add_ssh_known_host
{
  local host="$1"

  quiet_stderr ssh-keyscan \
    -H \
    -t "ecdsa,ed25519,rsa" \
    "${host}" >>"${known_hosts}"
}

function remove_ssh_known_host
{
  local host="$1"

  local known_hosts="${HOME}/.ssh/known_hosts"

  quiet ssh-keygen \
    -f "${known_hosts}" \
    -R "${host}"
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
