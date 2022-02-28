function main
{
  local encrypted_file
  encrypted_file="$(realpath "$1")"

  cat "${encrypted_file}" |
    gpg \
      --verbose \
      --decrypt |
    tar -xzv .
}

# Entry point
main "$1"
