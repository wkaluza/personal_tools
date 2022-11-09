set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function os_id
{
  local output

  output="$(cat "/etc/os-release" |
    grep -E '^ID=' |
    sed -E 's/^ID=(.+)$/\1/')"

  echo "${output}"
}

function run_based_on_os
{
  local fn_alpine="$1"

  local id
  id="$(os_id)"

  if [[ "${id}" == "alpine" ]]; then
    ${fn_alpine}
  else
    echo "Error: unrecognised OS ID ${id}"
    exit 1
  fi
}

function prep_package_manager_alpine
{
  apk update
  apk upgrade
}

function prep_package_manager
{
  run_based_on_os \
    prep_package_manager_alpine
}

function set_timezone_alpine
{
  apk add tzdata

  ln -sf \
    "/usr/share/zoneinfo/${TZ}" \
    "/etc/localtime"
  echo "${TZ}" >"/etc/timezone"
}

function set_timezone
{
  run_based_on_os \
    set_timezone_alpine
}

function install_trusted_ca_certs_alpine
{
  apk --no-cache add \
    ca-certificates

  cp \
    /docker/ca___/*.crt \
    "/usr/local/share/ca-certificates/"

  update-ca-certificates
}

function install_trusted_ca_certs
{
  run_based_on_os \
    install_trusted_ca_certs_alpine
}

function main
{
  prep_package_manager
  set_timezone
  install_trusted_ca_certs
}

main
