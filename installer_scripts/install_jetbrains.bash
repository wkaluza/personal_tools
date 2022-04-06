set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/../shell_script_imports/logging.bash"
source "${THIS_SCRIPT_DIR}/../shell_script_imports/common.bash"

function install_jetbrains_toolbox
{
  print_trace

  local jetbrains_toolbox_tar_gz_path="$(realpath "$1")"
  local install_destination="/opt/jetbrains/jetbrains-toolbox"

  if test -x "${install_destination}"; then
    log_info "jetbrains-toolbox already installed at ${install_destination}"
  else
    sudo apt-get install --yes \
      libfuse2

    sudo mkdir --parents "$(dirname "${install_destination}")"

    local archive_parent
    archive_parent="$(dirname "${jetbrains_toolbox_tar_gz_path}")"

    local now
    now="$(date --utc +'%Y%m%d%H%M%S%N')"

    local temp_dir
    temp_dir="$(realpath "${archive_parent}/deleteme_toolbox___${now}")"

    if test -d "${temp_dir}"; then
      log_error "Temp dir name conflict"
      exit 1
    fi

    mkdir --parents "${temp_dir}"

    tar --directory "${temp_dir}" -xzf "${jetbrains_toolbox_tar_gz_path}"

    local exe_file
    exe_file="$(find "${temp_dir}" -type f -executable)"

    if [[ "$(echo "${exe_file}" | wc -l)" != "1" ]]; then
      log_error "Expected one executable file, but found $(echo "${exe_file}" | wc -l)"
      exit 1
    fi

    sudo cp \
      "${exe_file}" \
      "${install_destination}"

    sudo chown \
      "$(id -u):$(id -g)" \
      "${install_destination}"

    if ! test -x "${install_destination}"; then
      log_error "File ${install_destination} is not executable"
      exit 1
    fi

    "${install_destination}" &
    disown

    rm -rf "${temp_dir}"
  fi
}

function main
{
  ensure_not_sudo

  local jetbrains_toolbox_tar_gz_path
  jetbrains_toolbox_tar_gz_path="$(realpath "$1")"

  if ! test -f "${jetbrains_toolbox_tar_gz_path}"; then
    log_error "Invalid path to jetbrains-toolbox archive: ${jetbrains_toolbox_tar_gz_path}"
    exit 1
  fi

  install_jetbrains_toolbox "${jetbrains_toolbox_tar_gz_path}"

  log_info "Success: $(basename $0)"
}

# Entry point
main "$1"
