set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

function main
{
  bash "${THIS_SCRIPT_DIR}/luks/mount.bash" \
    "sda" \
    "system"
  bash "${THIS_SCRIPT_DIR}/reset_infrastructure.bash"
  bash "${THIS_SCRIPT_DIR}/populate_pass_secrets.bash"
  bash "${THIS_SCRIPT_DIR}/upgrade_apt_full.bash"
  bash "${THIS_SCRIPT_DIR}/ensure_local_certs_exist.bash"
  bash "${THIS_SCRIPT_DIR}/build_docker_images.bash"
  bash "${THIS_SCRIPT_DIR}/enable_swarm_mode.bash"
  bash "${THIS_SCRIPT_DIR}/prepare_docker_swarm.bash"
  bash "${THIS_SCRIPT_DIR}/start_k8s.bash"
  bash "${THIS_SCRIPT_DIR}/cluster_connect.bash"
  bash "${THIS_SCRIPT_DIR}/start_dns.bash"
  bash "${THIS_SCRIPT_DIR}/configure_ssh.bash"
  bash "${THIS_SCRIPT_DIR}/configure_gogs.bash"
  bash "${THIS_SCRIPT_DIR}/push_docker_images.bash"
  bash "${THIS_SCRIPT_DIR}/bootstrap_infrastructure.bash"
  bash "${THIS_SCRIPT_DIR}/verify_services.bash"
  bash "${THIS_SCRIPT_DIR}/set_up_webhooks.bash"
  bash "${THIS_SCRIPT_DIR}/brightness_fix_laptop.bash"

  log_info "Success $(basename "$0")"
}

main
