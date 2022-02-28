set -euo pipefail

function create_user
{
  local uid="$1"
  local gid="$2"
  local username="$3"

  groupadd --gid "${gid}" "${username}"
  adduser \
    --disabled-password \
    --shell /bin/bash \
    --gecos "" \
    --uid "${uid}" \
    --gid "${gid}" \
    "${username}"
}

function allow_passwordless_sudo
{
  local username="$1"

  apt-get update
  apt-get upgrade --yes
  apt-get install --yes sudo
  adduser "${username}" sudo
  echo "%sudo ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
}

function create_workspace
{
  local workspace="$1"
  local uid="$2"
  local gid="$3"

  mkdir --parents "${workspace}"
  chown --recursive "${uid}:${gid}" "${workspace}"
}

function main
{
  local uid="$1"
  local gid="$2"
  local username="$3"
  local workspace="$4"

  create_user "${uid}" "${gid}" "${username}"
  allow_passwordless_sudo "${username}"
  create_workspace "${workspace}" "${uid}" "${gid}"
}

# Entry point
main "$1" "$2" "$3" "$4"
