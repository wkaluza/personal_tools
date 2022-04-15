set -euo pipefail
shopt -s inherit_errexit

function ensure_not_sudo
{
  if test "0" -eq "$(id -u)"; then
    echo "Do not run this as root"
    exit 1
  fi
}

function run_in_context
{
  local dir_path
  dir_path="$(realpath "$1")"
  local fn_arg="$2"

  mkdir --parents "${dir_path}"
  pushd "${dir_path}" >/dev/null
  ${fn_arg} "${@:3}"
  popd >/dev/null
}

function set_up_new_gpg_homedir
{
  local temp_gpg_homedir="$1"

  mkdir "${temp_gpg_homedir}"
  chmod "u+rwx,go-rwx" "${temp_gpg_homedir}"

  if test -z "${GNUPGHOME+a}"; then
    cp "${HOME}/.gnupg/gpg.conf" "${temp_gpg_homedir}"
  else
    cp "${GNUPGHOME}/gpg.conf" "${temp_gpg_homedir}"
  fi

  gpgconf --kill gpg-agent
  sleep 2
  gpgconf --kill scdaemon
  sleep 2

  gpg --list-keys >/dev/null
  sleep 2
  gpg --list-secret-keys >/dev/null
  sleep 2

  gpg --homedir "${temp_gpg_homedir}" --list-keys >/dev/null
  sleep 2
  gpg --homedir "${temp_gpg_homedir}" --list-secret-keys >/dev/null
  sleep 2
}

function up_to_128_random_hex_chars
{
  local num_chars="${1:-128}"

  local long
  long="$(
    dd if=/dev/urandom bs=4096 count=1 2>/dev/null |
      sha512sum |
      awk '{ print $1 }'
  )"

  echo -n "${long:0:num_chars}"
}

function os_version_codename
{
  local output

  output="$(source "/etc/os-release" && echo "${VERSION_CODENAME}")"

  echo "${output}"
}

function retry_until_success
{
  local task_name="$1"
  local command="$2"
  local args=("${@:3}")

  local i=1
  until ${command} "${args[@]}" >/dev/null 2>&1; do
    echo "Retrying: ${task_name}"

    i="$((i + 1))"
    if [[ ${i} -gt 30 ]]; then
      echo "Timed out: ${task_name}"
      exit 1
    fi

    sleep 5
  done

  if [[ ${i} -gt 1 ]]; then
    echo "Success (attempt ${i}): ${task_name}"
  fi
}

function file_sha256_digest
{
  local file_path="$1"

  cat "${file_path}" |
    sha256sum - |
    awk '{ print $1 }' |
    cut -c '1-8' -
}
