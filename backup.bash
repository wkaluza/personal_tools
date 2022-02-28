set -euo pipefail

THIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

function perform_backup
{
  local dir_source="$1"
  local dir_destination="$2"

  if test -d "$dir_source"; then
    mkdir --parents "$dir_destination"

    echo "Backing up ${dir_source} to ${dir_destination}"

    bash "${THIS_SCRIPT_DIR}/backups_tar/incremental_backup.bash" \
      "$dir_source" \
      "$dir_destination"
  fi
}

function sync_archive
{
  local dir_source="$1"
  local dir_destination="$2"

  if test -d "$dir_source"; then
    if test -d "$dir_destination"; then
      echo "Syncing archive ${dir_source} to ${dir_destination}"

      rsync \
        -avuX \
        --delete \
        "$dir_source" \
        "$dir_destination"

      # echo "Comparing archive ${dir_source} to ${dir_destination}"
      #
      # diff \
      #   --recursive \
      #   --no-dereference \
      #   "$dir_source" \
      #   "$dir_destination"
    fi
  fi
}

function sync_backups
{
  local dir_source="$1"
  local dir_destination="$2"

  if test -d "$dir_source"; then
    if test -d "$dir_destination"; then
      echo "Syncing backup ${dir_source} to ${dir_destination}"

      rsync \
        -avuX \
        --delete \
        "$dir_source" \
        "$dir_destination"

      # echo "Comparing backup ${dir_source} to ${dir_destination}"
      #
      # diff \
      #   --recursive \
      #   --no-dereference \
      #   "$dir_source" \
      #   "$dir_destination"
    fi
  fi
}

function main
{
  local dir_wk_home="$HOME/wk"
  local dir_wk_sda="$HOME/luks/pcspec_sda_luks/wk"

  local dir_backups_home="$HOME/backups"
  local dir_backups_sda="$HOME/luks/pcspec_sda_luks/backups"
  local dir_backups_sdb="$HOME/luks/pcspec_sdb_luks/backups"
  local dir_backups_sdc="$HOME/luks/pcspec_sdc_luks/backups"

  local dir_archive_home="$HOME/archive"
  local dir_archive_sda="$HOME/luks/pcspec_sda_luks/archive"
  local dir_archive_sdb="$HOME/luks/pcspec_sdb_luks/archive"
  local dir_archive_sdc="$HOME/luks/pcspec_sdc_luks/archive"

  perform_backup \
    "$dir_wk_home/" \
    "$dir_backups_home/backup_pcspec_home_wk/"
  perform_backup \
    "$dir_wk_sda/" \
    "$dir_backups_home/backup_pcspec_sda_wk/"

  sync_backups "$dir_backups_home/" "$dir_backups_sda/"
  sync_backups "$dir_backups_home/" "$dir_backups_sdb/"
  sync_backups "$dir_backups_home/" "$dir_backups_sdc/"

  sync_archive "$dir_archive_home/" "$dir_archive_sda/"
  sync_archive "$dir_archive_home/" "$dir_archive_sdb/"
  sync_archive "$dir_archive_home/" "$dir_archive_sdc/"

  echo Success
}

# Entry point
main
