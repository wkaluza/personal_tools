set -euo pipefail
if command -v shopt &>/dev/null; then
  shopt -s inherit_errexit
fi

function ensure_not_sudo
{
  if test "0" -eq "$(id -u)"; then
    log_error "Do not run this as root"
    exit 1
  fi
}

function run_in_context
{
  local dir_path
  dir_path="$(realpath "$1")"
  local fn_arg="$2"

  mkdir --parents "${dir_path}"
  quiet pushd "${dir_path}"
  ${fn_arg} "${@:3}"
  quiet popd
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

  quiet gpg --list-keys
  sleep 2
  quiet gpg --list-secret-keys
  sleep 2

  quiet gpg --homedir "${temp_gpg_homedir}" --list-keys
  sleep 2
  quiet gpg --homedir "${temp_gpg_homedir}" --list-secret-keys
  sleep 2
}

function hex
{
  cat - |
    xxd -ps |
    tr -d '\n'
}

function random_bytes
{
  local how_many="${1:-4096}"

  quiet_stderr dd \
    if=/dev/urandom \
    bs="${how_many}" \
    count=1
}

function os_version_codename
{
  local output

  output="$(source <(cat "/etc/os-release" |
    grep -E '^VERSION_CODENAME=') &&
    echo "${VERSION_CODENAME}")"

  echo "${output}"
}

function retry_until_success
{
  local task_name="$1"
  local command="$2"
  local args=("${@:3}")

  local i=1
  until quiet ${command} "${args[@]}"; do
    log_info "Retrying: ${task_name}"

    i="$((i + 1))"
    if [[ ${i} -gt 30 ]]; then
      log_error "Timed out: ${task_name}"
      exit 1
    fi

    sleep 5
  done

  if [[ ${i} -gt 1 ]]; then
    log_info "Success (attempt ${i}): ${task_name}"
  fi
}

function take_first
{
  local number_of_chars="$1"

  cat - |
    head -c "+${number_of_chars}"
}

function take_last
{
  local number_of_chars="$1"

  cat - |
    tail -c "-${number_of_chars}"
}

function drop_first
{
  local number_of_chars="$1"

  cat - |
    tail -c "+$((number_of_chars + 1))"
}

function drop_last
{
  local number_of_chars="$1"

  cat - |
    head -c "-${number_of_chars}"
}

function sha256
{
  cat - |
    sha256sum - |
    awk '{ print $1 }'
}

function md5
{
  cat - |
    md5sum - |
    awk '{ print $1 }'
}

function store_in_pass
{
  local id="$1"

  cat - |
    quiet pass insert \
      --force \
      --multiline \
      "${id}"
}

function current_timezone
{
  local output

  if command -v timedatectl &>/dev/null; then
    output="$(source <(timedatectl show |
      grep -E '^Timezone=') &&
      echo "${Timezone}")"
  else
    output="$(cat /etc/timezone)"
  fi

  echo "${output}"
}

function pass_show_or_generate
{
  local id="$1"
  local how_long="${2:-"32"}"

  if ! pass show "${id}" &>/dev/null; then
    random_bytes "${how_long}" |
      hex |
      store_in_pass "${id}"
  fi

  pass show "${id}"
}

function encrypt_deterministically
{
  local key
  key="$(echo -n "$1" |
    sha256 |
    take_first 16)"

  local secret_id="disposable_secret_160_${key}"

  local bytes
  bytes="$(pass_show_or_generate \
    "${secret_id}" \
    80)"

  cat - |
    openssl enc \
      -e \
      -aes-256-cbc \
      -salt \
      -pbkdf2 \
      -iter 1000000 \
      -iv "$(echo -n "${bytes}" | take_first 32)" \
      -K "$(echo -n "${bytes}" | drop_first 32 | take_first 64)" \
      -S "$(echo -n "${bytes}" | take_last 64)" \
      -md sha256 \
      -
}

function web_connection_working
{
  local host="example.com"

  quiet ping -c 1 "${host}"
}

function untar_gzip_to
{
  local archive
  archive="$(realpath "$1")"
  local target_dir
  target_dir="$(realpath "$2")"

  mkdir --parents "${target_dir}"

  tar \
    --directory "${target_dir}" \
    --extract \
    --file "${archive}" \
    --gzip
}

function filter
{
  local command="$1"
  local args=("${@:2}")

  local output
  output="$(mktemp)"

  if quiet_stderr ${command} "${args[@]}" >"${output}"; then
    cat "${output}"
  fi
}

function for_each
{
  local fn="$1"
  local args=("${@:2}")

  cat - | while read -r item; do
    ${fn} "${args[@]}" "${item}"
  done
}

function no_fail
{
  local fn="$1"
  local args=("${@:2}")

  ${fn} "${args[@]}" ||
    true
}

function run_with_env
{
  # function example_env_factory
  # {
  #   cat <<EOF
  # ENV_VAR1='some constant'
  # ENV_VAR2='${SOME_SCRIPT_VARIABLE}'
  # EOF
  # }

  local env_factory="$1"
  local command="$2"
  local args=("${@:3}")

  quiet env \
    --split-string "$(${env_factory} | tr '\n' ' ')" \
    "${command}" \
    "${args[@]}"
}

function strings_are_equal
{
  local one="$1"
  local two="$2"

  if [[ "${one}" != "${two}" ]]; then
    return 1
  fi
}

function list_shallow_subdirectories
{
  local depth="$1"
  local dir="$2"

  find "${dir}" \
    -maxdepth "${depth}" \
    -mindepth "${depth}" \
    -type d
}

function prepend
{
  local prefix="$1"
  while read -r line; do
    echo "${prefix}${line}"
  done
}
