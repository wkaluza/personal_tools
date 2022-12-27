set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi
THIS_SCRIPT_DIR="$(cd "$(dirname "$0")" >/dev/null 2>&1 && pwd)"
cd "${THIS_SCRIPT_DIR}"

source "${THIS_SCRIPT_DIR}/shell_script_imports/preamble.bash"

TEMP_UNPACK_DIR="$(mktemp -d)"

RSYNC_BASE_COMMAND="rsync -avuX --exclude '*/.idea/' --exclude '*/node_modules/'"

function on_exit
{
  rm -rf "${TEMP_UNPACK_DIR}"
}

trap on_exit EXIT

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

function names_diff
{
  local dir_source
  dir_source="$(realpath --canonicalize-missing "$1")"
  local dir_destination
  dir_destination="$(realpath --canonicalize-missing "$2")"

  diff \
    <(list_all_files_in "${dir_source}") \
    <(list_all_files_in "${dir_destination}")
}

function exact_diff
{
  local dir_source
  dir_source="$(realpath --canonicalize-missing "$1")"
  local dir_destination
  dir_destination="$(realpath --canonicalize-missing "$2")"

  diff \
    --recursive \
    --no-dereference \
    "${dir_source}" \
    "${dir_destination}"
}

function sync_with_deletion
{
  local dir_source
  dir_source="$(realpath "$1")"
  local dir_destination
  dir_destination="$(realpath "$2")"

  eval "${RSYNC_BASE_COMMAND}" \
    --delete \
    "${dir_source}/" \
    "${dir_destination}/"
}

function sync_without_deletion
{
  local dir_source
  dir_source="$(realpath "$1")"
  local dir_destination
  dir_destination="$(realpath "$2")"

  eval "${RSYNC_BASE_COMMAND}" \
    "${dir_source}/" \
    "${dir_destination}/"
}

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

function validate_backup
{
  local dir_reference
  dir_reference="$(realpath "$1")"
  local dir_backup
  dir_backup="$(realpath "$2")"

  local dir_restore
  dir_restore="${TEMP_UNPACK_DIR}/$(basename "${dir_backup}")"

  mkdir --parents "${dir_restore}"

  log_info "Restoring ${dir_backup} to ${dir_restore}"

  bash "${THIS_SCRIPT_DIR}/backup_tar/restore_backup.bash" \
    "${dir_restore}" \
    "${dir_backup}"

  log_info "Restoration done"

  local dir_restored_wk
  dir_restored_wk="${dir_restore}/$(basename "${dir_reference}")"

  log_info "Comparing ${dir_reference} to ${dir_restored_wk}..."

  if ! exact_diff \
    "${dir_reference}" \
    "${dir_restored_wk}"; then
    log_error "Comparison failed: ${dir_reference} and ${dir_restored_wk} are different"

    exit 1
  fi

  log_info "Comparison successful"
}

function perform_sync
{
  local dir_source
  dir_source="$(realpath --canonicalize-missing "$1")"
  local dir_destination
  dir_destination="$(realpath --canonicalize-missing "$2")"
  local sync_strategy="$3"
  local diff_strategy="$4"

  if test -d "${dir_source}" &&
    test -d "${dir_destination}"; then
    log_info "Syncing ${dir_source} to ${dir_destination}"

    quiet ${sync_strategy} \
      "${dir_source}" \
      "${dir_destination}"

    log_info "Comparing ${dir_source} to ${dir_destination}"

    quiet ${diff_strategy} \
      "${dir_source}" \
      "${dir_destination}"
  fi
}

function sync_archive
{
  local dir_source="$1"
  local dir_destination="$2"

  perform_sync \
    "${dir_source}" \
    "${dir_destination}" \
    sync_with_deletion \
    names_diff
}

function sync_backup
{
  local dir_source="$1"
  local dir_destination="$2"

  perform_sync \
    "${dir_source}" \
    "${dir_destination}" \
    sync_with_deletion \
    names_diff
}

function perform_and_validate_backup
{
  local dir_source="$1"
  local dir_backup="$2"

  perform_backup \
    "${dir_source}" \
    "${dir_backup}"
  validate_backup \
    "${dir_source}" \
    "${dir_backup}"
}

function main
{
  local dir_wk_home="${HOME}/wk"
  local dir_wk_sda="${HOME}/luks/pcspec_sda_luks/wk"

  local backup_copies="${HOME}/.wk_backup_copies___"
  local dir_wk_home_copy
  dir_wk_home_copy="${backup_copies}/wk_home/$(basename "${dir_wk_home}")"
  local dir_wk_sda_copy
  dir_wk_sda_copy="${backup_copies}/wk_sda/$(basename "${dir_wk_sda}")"

  local dir_backup_home="${HOME}/backup"
  local dir_backup_sda="${HOME}/luks/pcspec_sda_luks/backup"
  local dir_backup_sdb="${HOME}/luks/pcspec_sdb_luks/backup"
  local dir_backup_sdc="${HOME}/luks/pcspec_sdc_luks/backup"
  local dir_backup_sdd="${HOME}/luks/pcspec_sdd_luks/backup"
  local dir_backup_sde="${HOME}/luks/pcspec_sde_luks/backup"

  local dir_archive_home="${HOME}/archive"
  local dir_archive_sda="${HOME}/luks/pcspec_sda_luks/archive"
  local dir_archive_sdb="${HOME}/luks/pcspec_sdb_luks/archive"
  local dir_archive_sdc="${HOME}/luks/pcspec_sdc_luks/archive"
  local dir_archive_sdd="${HOME}/luks/pcspec_sdd_luks/archive"
  local dir_archive_sde="${HOME}/luks/pcspec_sde_luks/archive"

  log_info "Syncing target copies..."

  mkdir --parents "${dir_wk_home_copy}"
  mkdir --parents "${dir_wk_sda_copy}"

  quiet sync_with_deletion \
    "${dir_wk_home}" \
    "${dir_wk_home_copy}" &
  quiet sync_with_deletion \
    "${dir_wk_sda}" \
    "${dir_wk_sda_copy}" &

  wait
  log_info "Sync complete"

  perform_and_validate_backup \
    "${dir_wk_home_copy}" \
    "${dir_backup_home}/backup_pcspec_home_wk"
  perform_and_validate_backup \
    "${dir_wk_sda_copy}" \
    "${dir_backup_home}/backup_pcspec_sda_wk"

  sync_backup "${dir_backup_home}" "${dir_backup_sda}"
  sync_backup "${dir_backup_home}" "${dir_backup_sdb}"
  sync_backup "${dir_backup_home}" "${dir_backup_sdc}"
  sync_backup "${dir_backup_home}" "${dir_backup_sdd}"
  sync_backup "${dir_backup_home}" "${dir_backup_sde}"

  sync_archive "${dir_archive_home}" "${dir_archive_sda}"
  sync_archive "${dir_archive_home}" "${dir_archive_sdb}"
  sync_archive "${dir_archive_home}" "${dir_archive_sdc}"
  sync_archive "${dir_archive_home}" "${dir_archive_sdd}"
  sync_archive "${dir_archive_home}" "${dir_archive_sde}"

  log_info "Success: $(basename "$0")"
}

# Entry point
main
