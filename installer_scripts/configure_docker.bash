set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function build_docker_pass_credential_helper
{
  print_trace

  local host_installation_dir="$1"

  local destination_path="${host_installation_dir}/docker-credential-pass"

  mkdir --parents "${host_installation_dir}"
  if test -x "${destination_path}"; then
    log_info "docker-credential-pass already installed"
  else
    local random_tag
    random_tag="$(random_bytes 8 | hex | take_first 16)"
    local random_name
    random_name="$(random_bytes 8 | hex | take_first 16)"

    docker build \
      --file "${THIS_SCRIPT_DIR}/build_docker_cred_helper.dockerfile" \
      --tag "${random_tag}" \
      "${THIS_SCRIPT_DIR}/build_docker_cred_helper_context"

    docker run \
      --name "${random_name}" \
      "${random_tag}" \
      sleep 0

    docker cp \
      "${random_name}:/workspace/docker-credential-pass" \
      "${destination_path}"

    chmod u+rwx,go-rwx "${destination_path}"
  fi
}

function install_docker_pass_credential_helper
{
  print_trace

  sudo apt-get install --yes \
    jq

  local dest_dir="${HOME}/.local/bin"
  local docker_config="${HOME}/.docker/config.json"

  local temp_cred_helper_dir
  temp_cred_helper_dir="$(mktemp -d)"
  run_in_context \
    "${temp_cred_helper_dir}" \
    build_docker_pass_credential_helper \
    "${dest_dir}"

  if ! test -f "${docker_config}"; then
    mkdir --parents "$(dirname "${docker_config}")"
    touch "${docker_config}"
    chmod 600 "${docker_config}"
    echo '{}' >"${docker_config}"
  fi

  local temp_docker_config
  temp_docker_config="$(mktemp)"
  cp "${docker_config}" "${temp_docker_config}"
  cat "${temp_docker_config}" |
    jq --sort-keys \
      '. + { "credsStore": "pass" }' \
      - >"${docker_config}"
}

function install_docker_compose_if_absent
{
  sudo apt-get install --yes \
    curl

  local docker_plugins_dir="${HOME}/.docker/cli-plugins"
  local plugin_version="2.2.3"
  local download_url="https://github.com/docker/compose/releases/download"

  if quiet docker compose version; then
    log_info "docker compose already installed"
  else
    mkdir --parents "${docker_plugins_dir}"
    curl -sSL \
      "${download_url}/v${plugin_version}/docker-compose-linux-x86_64" \
      -o "${docker_plugins_dir}/docker-compose"
    chmod u+x "${docker_plugins_dir}/docker-compose"

    if ! docker compose version | quiet grep "${plugin_version}"; then
      log_error "Unexpected docker compose version number"
      exit 1
    fi
  fi
}

function main
{
  ensure_not_sudo

  install_docker_pass_credential_helper
  # install_docker_compose_if_absent

  log_info "Success: $(basename "$0")"
}

# Entry point
main
