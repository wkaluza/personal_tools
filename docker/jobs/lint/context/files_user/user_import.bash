set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function install_yq
{
  python3 -m pip install \
    yq==3.0.1
}

function configure_node
{
  cat <<'EOF' >>"${DOCKER_PROFILE}"
export PATH="${HOME}/.yarn/bin:${PATH}"
EOF

  source "${DOCKER_PROFILE}"
}

function install_prettier
{
  yarn --non-interactive --silent global \
    add \
    "prettier@2.6.2"
}

function configure_go
{
  cat <<'EOF' >>"${DOCKER_PROFILE}"
export PATH="${HOME}/go/bin:${PATH}"
EOF

  source "${DOCKER_PROFILE}"
}

function install_shfmt
{
  go install "mvdan.cc/sh/v3/cmd/shfmt@v3.4.3"
}

function install_kubectl
{
  local output_path="${HOME}/.local/bin/kubectl"
  local version="v1.25.2"
  # version="$(curl -L -s https://dl.k8s.io/release/stable.txt)"

  curl \
    --location \
    --output "${output_path}" \
    --silent \
    "https://dl.k8s.io/release/${version}/bin/linux/amd64/kubectl"

  chmod "u+x" "${output_path}"
}
