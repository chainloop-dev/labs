# helpers
t=$(date "+%Y%m%d%H%M%S")
script_dir="$(cd "$(dirname "$0")" && pwd)"

log() {
  # echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
  yellow "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

log_error() {
  red_bold "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

log_header() {
  blue_bold "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

validate_chainloop_required_env_vars() {
  if [ -z "${CHAINLOOP_ROBOT_ACCOUNT}" ]; then
    log_error "CHAINLOOP_ROBOT_ACCOUNT is not set"
    return 1
  fi
  if [ -z "${CHAINLOOP_VERSION+x}" ]; then
    CHAINLOOP_VERSION=""
  fi
  if [ -z "${CHAINLOOP_SIGNING_KEY}" ]; then
    log_error "CHAINLOOP_SIGNING_KEY is not set"
    return 1
  fi
  if [[ -z "${CHAINLOOP_SIGNING_PASSWORD+x}" ]]; then
    log_error "CHAINLOOP_SIGNING_PASSWORD is not set"
    return 1
  fi
}

install_chainloop_tools() {
  log_header "Installing Chainloop Tools"
  export PATH=/usr/local/bin:$PATH

  if [ -f /usr/local/bin/chainloop ]; then
    log "Skipping... Chainloop Tools already installed"
    return 0
  fi

  curl -sL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
  if [ $? -ne 0 ]; then
    log_error "Cosign installation failed"
    return 1
  fi
  chmod +x /usr/local/bin/cosign

  log "Installing Chainloop CLI"
  if [ -n "${CHAINLOOP_VERSION}" ]; then
    curl -sfL https://docs.chainloop.dev/install.sh | bash -s -- --version v${CHAINLOOP_VERSION}
  else
    curl -sfL https://docs.chainloop.dev/install.sh | bash -s
  fi
  if [ $? -ne 0 ]; then
    log_error "Chainloop installation failed"
    return 1
  fi

  log "Installing Syft, Oras, Cosign, and jq"

  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
  if [ $? -ne 0 ]; then
    log_error "Syft installation failed"
    return 1
  fi

  python3 -m pip install semgrep
  
  VERSION="1.0.0"
  curl -LO "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz"
  mkdir -p oras-install/
  tar -zxf oras_${VERSION}_*.tar.gz -C oras-install/
  sudo mv oras-install/oras /usr/local/bin/
  rm -rf oras_${VERSION}_*.tar.gz oras-install/
  oras version
  if [ $? -ne 0 ]; then
    log_error "Oras installation failed"
    return 1
  fi

  sudo apt-get install jq ruby -y
  if [ $? -ne 0 ]; then
    log_error "jq installation failed"
    return 1
  fi

  sudo gem install rest-client

  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  sudo chmod a+x /usr/local/bin/yq
  if [ $? -ne 0 ]; then
    log_error "yq installation failed"
    return 1
  fi

  log "Installing Parlay"
  wget https://github.com/snyk/parlay/releases/download/v0.2.0/parlay_Linux_x86_64.tar.gz
  tar -xvf parlay_Linux_x86_64.tar.gz
  sudo mv parlay /usr/local/bin/
  rm parlay_Linux_x86_64.tar.gz
}

spdx2cyclonedx() {
  spdx_file=$1
  cyclonedx_file=$2
  syft convert "${spdx_file}" -o cyclonedx-json="${cyclonedx_file}"
  if [ $? -ne 0 ]; then
    log_error "SPDX to CycloneDX conversion failed"
    return 1
  fi
}

process_metadata() {
  log "Preparing metadata for $artifact"
  case "$kind" in
  # Each method should set pairs with the list of metadata to add to the attestation
  "vac")
    prepare_metadata_for_vac_artifact
    ;;
  "bitnami")
    prepare_metadata_for_bitnami_artifact
    ;;
  "oci")
    prepare_metadata_for_oci_artifact
    ;;
  "helm_chart")
    prepare_metadata_for_helm_chart_artifact
    ;;
  *)
    log_error "Unknown artifact kind: $kind"
    return 1
    ;;
  esac
  if [ $? -ne 0 ]; then
    log_error "Failed to prepare metadata for $kind artifact"
    return 1
  fi
  log "Preparing metadata for $artifact: DONE"
  
  if [ $kind != "helm_chart" ] ; then
    if [ ! -f spdx.json ]; then
      syft -o spdx-json $uri > spdx.json
    fi
    if [ ! -f cyclonedx.json ]; then
      syft -o cyclonedx-json $uri > cyclonedx.json
    fi
    
    parlay scorecard enrich cyclonedx.json | jq > cyclonedx-scorecard.json
    parlay ecosystems enrich cyclonedx-scorecard.json | jq > cyclonedx-scorecard-ecosystems.json
    parlay snyk enrich cyclonedx-scorecard-ecosystems.json | jq > cyclonedx-enriched.json
  fi
  
  for ((i = 0; i < ${#METADATA[@]}; i += 2)); do
    k=${METADATA[i]}
    v=${METADATA[i + 1]}
    if [[ $v != *.* ]]; then
      v=$(eval "echo \$$v")
    fi

    log "Adding ${k}=${v} to attestation"
    chainloop attestation add --name "${k}" --value "${v}"
    if [ $? -ne 0 ]; then
      log_error "Failed to add ${k} to attestation"
      return 1
    fi
  done
}

# chainloop_adapter_run "${args['kind']}" "${args['registry_uri']}" "${args['artifacts']}"
chainloop_adapter_run() {
  kind=$1
  repo=$2
  artifacts=$3

  CHLP_TMPDIR="tmp/chainloop/adapter/${t}/${kind}/"

  mkdir -p $CHLP_TMPDIR

  # validations
  if [[ ! $artifacts =~ ^[[:alnum:].,:-]+$ ]]; then
    log_error "containers must be a comma-separated list of alphanumeric strings"
    exit 1
  fi

  IFS=',' read -ra vals <<<"$artifacts"
  for a in "${vals[@]}"; do
    cdir=$(pwd)
    tdir="${CHLP_TMPDIR}/$a"
    mkdir -p "${tdir}"
    cd "${tdir}"
    
    ###
    # $repo
    artifact=$a
    uri="${repo}/${artifact}"
    tag="latest"
    app_id="${artifact}"
    if [[ "$artifact" == *:* ]]; then
      tag="${artifact##*:}"
      app_id="${artifact%:*}"
    fi
    full_uri="${repo}/${app_id}:${tag}"
    app_path="${kind}/${app_id}:${tag}"
    ###

    # Save the original file descriptors for stdout (1) and stderr (2)
    exec 3>&1 4>&2
    # Redirect both stdout and stderr to a file and screen using tee
    exec > >(tee "output.log") 2>&1

    log_header "Processing ${kind} ${repo} - artifacts $artifacts"
    log_header "  processing artifact: $app_id - $full_uri"
    log "Initializing Chainloop Attestation"
    chainloop attestation init -f # --contract-revision 1
    if [ $? -ne 0 ]; then
      log_error "Chainloop initialization failed"
      exit 1
    fi

    log "Initializing Chainloop Attestation: DONE"
    process_metadata

    if [ $? -ne 0 ]; then
      log_error "Chainloop attestation failed."
      chainloop attestation reset
      # chainloop attestation reset --trigger cancellation
      exit 1
    fi
    chainloop attestation status --full

    # Restore the original file descriptors 
    exec 1>&3 2>&4
    # Close the saved file descriptors
    exec 3>&- 4>&-

    chainloop attestation add --name log --value output.log
  
    # chainloop attestation push --key env://CHAINLOOP_SIGNING_KEY
    chainloop attestation push --key env://CHAINLOOP_SIGNING_KEY --annotation id=$app_id,path=$app_path

    cd "${cdir}"
  done
}

chainloop_attestation_add_from_yaml() {
  script=`cat .chainloop.yml | yq eval '.attestation[] | "chainloop attestation add --name "  + .name + " --value " + .path + "; "'`
  eval $script
}

chainloop_attestation_status() {
  chainloop attestation status --full &> c8-status.txt
  cat c8-status.txt
}

chainloop_attestation_push() {
  chainloop attestation push --key env://CHAINLOOP_SIGNING_KEY &> c8-push.txt
  cat c8-push.txt
}

chainloop_generate_github_summary() {
  digest=`cat c8-push.txt| grep " Digest: " | awk -F\  '{print $3}'`
  echo -e "## Great job!\nYou are making SecOps and Compliance teams really happy. Keep up the good work!\n" >> $GITHUB_STEP_SUMMARY
  echo "**[Chainloop Trust Report](https://app.chainloop.dev/attestation/${digest})**" >> $GITHUB_STEP_SUMMARY 
  echo "\`\`\`" >> $GITHUB_STEP_SUMMARY 
  cat c8-status.txt >> $GITHUB_STEP_SUMMARY
  echo "\`\`\`" >> $GITHUB_STEP_SUMMARY 
}