is_chainloop_in_path() {
  if command -v chainloop &> /dev/null; then
    # we are good
    return 0
  else
    log "chainloop is not in PATH, install it."
    return 1
  fi
}

validate_env() {
    if [ ! is_chainloop_in_path ] ; then
        exit 1
    fi
}

l() {
  yellow "$*"
}

data_path=/tmp/chainloop/data
mkdir -p "$data_path"

store_attestation_uuid() {
    sha256="$1"
    uuid="$2"
    name="$3"
    mkdir -p "${data_path}/$sha256"
    echo "$uuid $name" >> "${data_path}/$sha256/uuids.txt"
}


get_attestations_uuids() {
    sha256="$1"
    if [[ -f "${data_path}/$sha256/uuids.txt" ]]; then
        cat "${data_path}/$sha256/uuids.txt"
    else
        echo "No attestations found for SHA256: $sha256"
    fi
}

