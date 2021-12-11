#!/usr/bin/env bash

set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

CREDENTIAL_HELPERS_DIR="${THIS_SCRIPT_DIR}/docker_credential_helpers___deleteme"

function on_exit {
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    rm -rf "${CREDENTIAL_HELPERS_DIR}"
  fi

  exit $exit_code
}

trap on_exit EXIT

function install_basics {
  print_trace

  sudo apt-get update >/dev/null
  DEBIAN_FRONTEND=noninteractive sudo \
    --preserve-env=DEBIAN_FRONTEND apt-get install -y \
    git \
    jq \
    make \
    pass >/dev/null
}

function build_docker_pass_credential_helper {
  print_trace

  local host_installation_dir="$1"
  local docker_mount_dir="/external_mount"

  local random_tag
  random_tag="$(up_to_128_random_hex_chars 16)"

  local temp_docker_ctx
  temp_docker_ctx="docker_ctx_${random_tag}_deleteme___"
  mkdir --parents "${temp_docker_ctx}"

  cat <<EOF >>"${temp_docker_ctx}/build.bash"
  set -euo pipefail

  function install_basics_inner {
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      curl \
      make \
      git
  }

  function install_golang {
    local go_archive="go.tar.gz"
    local v="1.17.2"
    local download_url="https://dl.google.com/go/go\${v}.linux-amd64.tar.gz"

    local target_dir="/usr/local"
    export PATH="\${PATH}:\${target_dir}/go/bin"

    if test -d "\${target_dir}/go"; then
      echo "golang is already installed"
      go version
    else
      curl -fsSL --output "./\${go_archive}" "\${download_url}"
      mv "./\${go_archive}" "\${target_dir}"

      pushd "\${target_dir}"
      tar -xzf "./\${go_archive}"
      rm "./\${go_archive}"
      popd
    fi
  }

  function main {
    local temp_dir="temp"

    install_basics_inner
    install_golang

    git clone \
      "https://github.com/docker/docker-credential-helpers.git" \
      "\${temp_dir}"

    pushd "\${temp_dir}"
    make pass
    popd
  }

  # Entry point
  main
EOF

  cat <<EOF >>"${temp_docker_ctx}/temp.dockerfile"
FROM ubuntu:focal
WORKDIR /workspace
COPY build.bash /workspace/
RUN bash /workspace/build.bash
EOF

  docker build \
    -t "${random_tag}" \
    -f "${temp_docker_ctx}/temp.dockerfile" \
    "${temp_docker_ctx}"

  local host_mount_dir="${temp_docker_ctx}/shared_dir"
  mkdir --parents "${host_mount_dir}"

  docker run \
    --rm \
    -v "$(realpath "${host_mount_dir}"):${docker_mount_dir}" \
    "${random_tag}" \
    mv "/workspace/temp/bin/docker-credential-pass" "${docker_mount_dir}"
  log_info "Need to change file ownership of docker-credential-pass"
  sudo chown "$(id -u)" "${host_mount_dir}/docker-credential-pass"
  chmod 700 "${host_mount_dir}/docker-credential-pass"

  mv \
    "${host_mount_dir}/docker-credential-pass" \
    "${host_installation_dir}/"
}

function configure_docker {
  print_trace

  local dest_dir="${HOME}/.local/bin"
  local docker_config="${HOME}/.docker/config.json"

  mkdir --parents "${dest_dir}"

  run_in_context \
    "${CREDENTIAL_HELPERS_DIR}" \
    build_docker_pass_credential_helper \
    "${dest_dir}"

  echo "export PATH=\"\$PATH:${dest_dir}\"" >>"${HOME}/.bashrc"
  source "${HOME}/.bashrc"

  if ! test -f "${docker_config}"; then
    mkdir --parents "$(dirname "${docker_config}")"
    touch "${docker_config}"
    chmod 600 "${docker_config}"
    echo '{}' >"${docker_config}"
  fi

  cp "${docker_config}" "${docker_config}.temp"
  jq --sort-keys \
    '. | { "credsStore": "pass" }' \
    "${docker_config}" >"${docker_config}.temp"
  mv "${docker_config}.temp" "${docker_config}"
}

function main {
  ensure_not_sudo

  install_basics
  configure_docker

  echo Success
}

# Entry point
main
