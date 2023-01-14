set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

_THIS_FILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

source <(cat "${_THIS_FILE_DIR}/local_domains.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '.[]' - |
  sort)

source <(cat "${_THIS_FILE_DIR}/managed_local_secret_ids.json" |
  jq '. | to_entries' - |
  jq '. | map( "\(.key)=\"\(.value)\"" )' - |
  jq --raw-output '.[]' - |
  sort)

source "${_THIS_FILE_DIR}/internal/common.bash"
source "${_THIS_FILE_DIR}/internal/docker.bash"
source "${_THIS_FILE_DIR}/internal/git_helpers.bash"
source "${_THIS_FILE_DIR}/internal/gogs_helpers.bash"
source "${_THIS_FILE_DIR}/internal/logging.bash"
source "${_THIS_FILE_DIR}/internal/ssh_helpers.bash"
source "${_THIS_FILE_DIR}/internal/k8s_helpers.bash"
source "${_THIS_FILE_DIR}/internal/secret_helpers.bash"
