set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/preamble.bash"

function main
{
  local commit="${1:-"HEAD"}"

  local project_root_dir
  project_root_dir="$(realpath "${THIS_SCRIPT_DIR}/..")"

  local workspace_path="/workspace"

  docker run \
    --interactive \
    --rm \
    --tty \
    --volume "${project_root_dir}:${workspace_path}" \
    --workdir "${workspace_path}" \
    "private.docker.localhost/local/lint:1" \
    "./" \
    "${commit}"

  log_info "Success $(basename "$0")"
}

main "$@"
