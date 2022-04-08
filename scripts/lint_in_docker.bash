set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

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
