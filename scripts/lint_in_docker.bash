set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

function main
{
  local project_root_dir
  project_root_dir="$(realpath "${THIS_SCRIPT_DIR}/..")"

  bash "${project_root_dir}/docker/run_in_docker.bash" \
    "${project_root_dir}" \
    "${project_root_dir}/docker/docker_jobs.json" \
    "lint"

  echo "Success: $(basename "$0")"
}

# Entry point
main
