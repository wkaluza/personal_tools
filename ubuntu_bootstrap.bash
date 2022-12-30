set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function download_latest_personal_tools
{
  local temp_dir="$1"
  local url="$2"

  local temp_file
  temp_file="$(mktemp)"

  curl \
    -fsSL \
    --output - \
    "${url}" >"${temp_file}"

  unzip \
    "${temp_file}" \
    -d "${temp_dir}" &>/dev/null
}

function main
{
  local repo_name="personal_tools"
  local branch_name="main"
  local url="https://github.com/wkaluza/${repo_name}/archive/refs/heads/${branch_name}.zip"

  local temp_dir
  temp_dir="$(mktemp -d)"

  local repo_dir="${temp_dir}/${repo_name}-${branch_name}"

  download_latest_personal_tools \
    "${temp_dir}" \
    "${url}"

  pushd "${repo_dir}" >/dev/null
  bash "${repo_dir}/installer_scripts/ubuntu_bare_minimum.bash"
  popd >/dev/null

  echo "Success: $(basename "$0")"
}

main
