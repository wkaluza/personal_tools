set -euo pipefail
shopt -s inherit_errexit

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

source "${THIS_SCRIPT_DIR}/shell_script_imports/logging.bash"

function perform_backup
{
  local dir_source
  dir_source="$(realpath --canonicalize-missing "$1")"
  local dir_destination
  dir_destination="$(realpath --canonicalize-missing "$2")"

  if test -d "${dir_source}"; then
    mkdir --parents "${dir_destination}"

    log_info "Backing up ${dir_source} to ${dir_destination}"

    bash "${THIS_SCRIPT_DIR}/backup_tar/incremental_backup.bash" \
      "${dir_source}" \
      "${dir_destination}"
  fi
}

function list_all_files_in
{
  local dir_to_search
  dir_to_search="$(realpath "$1")"

  find \
    "${dir_to_search}" \
    -type f \
    -exec realpath \
    --relative-to="$(dirname "${dir_to_search}")" \
    -- {} \; |
    sort |
    uniq
}

function sync_archive
{
  local dir_source
  dir_source="$(realpath --canonicalize-missing "$1")"
  local dir_destination
  dir_destination="$(realpath --canonicalize-missing "$2")"

  if test -d "${dir_source}" && test -d "${dir_destination}"; then
    log_info "Syncing archive ${dir_source} to ${dir_destination}"

    rsync \
      -avuX \
      "${dir_source}/" \
      "${dir_destination}/"

    log_info "Comparing archive ${dir_source} to ${dir_destination}"

    diff \
      <(list_all_files_in "${dir_source}") \
      <(list_all_files_in "${dir_destination}")

    # diff \
    #   --recursive \
    #   --no-dereference \
    #   "${dir_source}" \
    #   "${dir_destination}"
  fi
}

function sync_backup
{
  local dir_source
  dir_source="$(realpath --canonicalize-missing "$1")"
  local dir_destination
  dir_destination="$(realpath --canonicalize-missing "$2")"

  if test -d "${dir_source}" && test -d "${dir_destination}"; then
    log_info "Syncing backup ${dir_source} to ${dir_destination}"

    rsync \
      -avuX \
      --delete \
      "${dir_source}/" \
      "${dir_destination}/"

    log_info "Comparing backup ${dir_source} to ${dir_destination}"

    diff \
      --recursive \
      --no-dereference \
      "${dir_source}" \
      "${dir_destination}"
  fi
}

function main
{
  local dir_wk_home="${HOME}/wk"
  local dir_wk_sda="${HOME}/luks/pcspec_sda_luks/wk"

  local dir_backup_home="${HOME}/backup"
  local dir_backup_sda="${HOME}/luks/pcspec_sda_luks/backup"
  local dir_backup_sdb="${HOME}/luks/pcspec_sdb_luks/backup"
  local dir_backup_sdc="${HOME}/luks/pcspec_sdc_luks/backup"

  local dir_archive_home="${HOME}/archive"
  local dir_archive_sda="${HOME}/luks/pcspec_sda_luks/archive"
  local dir_archive_sdb="${HOME}/luks/pcspec_sdb_luks/archive"
  local dir_archive_sdc="${HOME}/luks/pcspec_sdc_luks/archive"

  perform_backup \
    "${dir_wk_home}" \
    "${dir_backup_home}/backup_pcspec_home_wk"
  perform_backup \
    "${dir_wk_sda}" \
    "${dir_backup_home}/backup_pcspec_sda_wk"

  sync_backup "${dir_backup_home}" "${dir_backup_sda}"
  sync_backup "${dir_backup_home}" "${dir_backup_sdb}"
  sync_backup "${dir_backup_home}" "${dir_backup_sdc}"

  sync_archive "${dir_archive_home}" "${dir_archive_sda}"
  sync_archive "${dir_archive_home}" "${dir_archive_sdb}"
  sync_archive "${dir_archive_home}" "${dir_archive_sdc}"

  log_info "Success: $(basename "$0")"
}

# Entry point
main
