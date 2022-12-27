set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local repo_name="personal_tools"
  local branch_name="main"
  local url="https://github.com/wkaluza/${repo_name}/archive/refs/heads/${branch_name}.zip"

  local temp_file
  temp_file="$(mktemp)"
  local temp_dir
  temp_dir="$(mktemp -d)"

  local repo_dir="${temp_dir}/${repo_name}-${branch_name}"

  curl -fsSL --output - "${url}" >"${temp_file}"
  unzip "${temp_file}" -d "${temp_dir}" >/dev/null

  pushd "${repo_dir}" >/dev/null
  bash "${repo_dir}/installer_scripts/ubuntu_bare_minimum.bash"
  popd >/dev/null

  echo "Success: $(basename "$0")"
}

main
