set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

BASHRC="${HOME}/.bashrc"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

CREDENTIAL_HELPERS_DIR="${THIS_SCRIPT_DIR}/docker_credential_helpers___deleteme"

function on_exit
{
  local exit_code=$?

  if [[ ${exit_code} -eq 0 ]]; then
    rm -rf "${CREDENTIAL_HELPERS_DIR}"
  fi

  exit "${exit_code}"
}

trap on_exit EXIT

function build_docker_pass_credential_helper
{
  print_trace

  local host_installation_dir="$1"

  mkdir --parents "${host_installation_dir}"

  if test -x "${host_installation_dir}/docker-credential-pass"; then
    log_info "docker-credential-pass already installed"
  else
    local docker_mount_dir="/external_mount"

    local random_tag
    random_tag="$(up_to_128_random_hex_chars 16)"

    cat <<EOF | docker build \
      --tag "${random_tag}" \
      -
FROM ubuntu:focal
WORKDIR /workspace
RUN echo "set -euo pipefail \n \
\n \
function install_basics_inner { \n \
  apt-get update \n \
  apt-get install --yes \
    curl \
    make \
    git \n \
} \n \
\n \
function install_golang { \n \
  local go_archive=\"go.tar.gz\" \n \
  local v=\"1.17.5\" \n \
  local download_url=\"https://dl.google.com/go/go\\\${v}.linux-amd64.tar.gz\" \n \
\n \
  local target_dir=\"/usr/local\" \n \
  export PATH=\"\\\${PATH}:\\\${target_dir}/go/bin\" \n \
\n \
  if test -d \"\\\${target_dir}/go\"; then \n \
    echo \"golang is already installed\" \n \
    go version \n \
  else \n \
    curl -fsSL --output \"./\\\${go_archive}\" \"\\\${download_url}\" \n \
    mv \"./\\\${go_archive}\" \"\\\${target_dir}\" \n \
\n \
    pushd \"\\\${target_dir}\" \n \
    tar -xzf \"./\\\${go_archive}\" \n \
    rm \"./\\\${go_archive}\" \n \
    popd \n \
  fi \n \
} \n \
\n \
function main { \n \
  local temp_dir=\"temp\" \n \
\n \
  install_basics_inner \n \
  install_golang \n \
\n \
  git clone \
    \"https://github.com/docker/docker-credential-helpers.git\" \
    \"\\\${temp_dir}\" \n \
\n \
  pushd \"\\\${temp_dir}\" \n \
  make pass \n \
  popd \n \
} \n \
\n \
main \n \
" | bash -
EOF

    local uid
    uid="$(id -u)"
    local gid
    gid="$(id -g)"

    local cmd="mv \
\"/workspace/temp/bin/docker-credential-pass\" \
\"${docker_mount_dir}\" \
&& \
chown ${uid}:${gid} \"${docker_mount_dir}/docker-credential-pass\" \
&& \
chmod 700 \"${docker_mount_dir}/docker-credential-pass\""

    docker run \
      --rm \
      --volume "${host_installation_dir}:${docker_mount_dir}" \
      "${random_tag}" \
      bash -c "${cmd}"

    docker rmi \
      --no-prune \
      "${random_tag}"
  fi
}

function install_docker_pass_credential_helper
{
  print_trace

  sudo apt-get install --yes \
    jq

  local dest_dir="${HOME}/.local/bin"
  local docker_config="${HOME}/.docker/config.json"

  run_in_context \
    "${CREDENTIAL_HELPERS_DIR}" \
    build_docker_pass_credential_helper \
    "${dest_dir}"

  echo "export PATH=\"\${PATH}:${dest_dir}\"" >>"${BASHRC}"
  source "${BASHRC}"

  if ! test -f "${docker_config}"; then
    mkdir --parents "$(dirname "${docker_config}")"
    touch "${docker_config}"
    chmod 600 "${docker_config}"
    echo '{}' >"${docker_config}"
  fi

  cp "${docker_config}" "${docker_config}.temp"
  jq --sort-keys \
    '. | { "credsStore": "pass" }' \
    "${docker_config}.temp" >"${docker_config}"
  rm "${docker_config}.temp"
}

function install_docker_compose_if_absent
{
  sudo apt-get install --yes \
    curl

  local docker_plugins_dir="${HOME}/.docker/cli-plugins"
  local plugin_version="2.2.3"
  local download_url="https://github.com/docker/compose/releases/download"

  if docker compose version >/dev/null 2>&1; then
    log_info "docker compose already installed"
  else
    mkdir --parents "${docker_plugins_dir}"
    curl -sSL \
      "${download_url}/v${plugin_version}/docker-compose-linux-x86_64" \
      -o "${docker_plugins_dir}/docker-compose"
    chmod u+x "${docker_plugins_dir}/docker-compose"

    if ! docker compose version | grep "${plugin_version}" >/dev/null 2>&1; then
      log_error "Unexpected docker compose version number"
      exit 1
    fi
  fi
}

function main
{
  ensure_not_sudo

  install_docker_pass_credential_helper
  install_docker_compose_if_absent

  log_info "Success: $(basename "$0")"
}

# Entry point
main
