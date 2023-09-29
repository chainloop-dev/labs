## Usage:
## Use any of the functions below to color or format a portion of a string.
##
##   echo "before $(red this is red) after"
##   echo "before $(green_bold this is green_bold) after"
##
## Color output will be disabled if `NO_COLOR` environment variable is set
## in compliance with https://no-color.org/
##
print_in_color() {
  local color="$1"
  shift
  if [[ -z ${NO_COLOR+x} ]]; then
    printf "$color%b\e[0m\n" "$*"
  else
    printf "%b\n" "$*"
  fi
}

red() { print_in_color "\e[31m" "$*"; }
green() { print_in_color "\e[32m" "$*"; }
yellow() { print_in_color "\e[33m" "$*"; }
blue() { print_in_color "\e[34m" "$*"; }
magenta() { print_in_color "\e[35m" "$*"; }
cyan() { print_in_color "\e[36m" "$*"; }
bold() { print_in_color "\e[1m" "$*"; }
underlined() { print_in_color "\e[4m" "$*"; }
red_bold() { print_in_color "\e[1;31m" "$*"; }
green_bold() { print_in_color "\e[1;32m" "$*"; }
yellow_bold() { print_in_color "\e[1;33m" "$*"; }
blue_bold() { print_in_color "\e[1;34m" "$*"; }
magenta_bold() { print_in_color "\e[1;35m" "$*"; }
cyan_bold() { print_in_color "\e[1;36m" "$*"; }
red_underlined() { print_in_color "\e[4;31m" "$*"; }
green_underlined() { print_in_color "\e[4;32m" "$*"; }
yellow_underlined() { print_in_color "\e[4;33m" "$*"; }
blue_underlined() { print_in_color "\e[4;34m" "$*"; }
magenta_underlined() { print_in_color "\e[4;35m" "$*"; }
cyan_underlined() { print_in_color "\e[4;36m" "$*"; }

###

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

###
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

###

install_chainloop_cli() {
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
}

install_cosign() {
  log "Installing Cosign"
  curl -sL https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o /usr/local/bin/cosign
  if [ $? -ne 0 ]; then
    log_error "Cosign installation failed"
    return 1
  fi
  chmod +x /usr/local/bin/cosign
}

install_chainloop_cli_and_cosign() {
  install_cosign
  install_chainloop_cli
}

install_syft() {
  log "Installing Syft"
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
  if [ $? -ne 0 ]; then
    log_error "Syft installation failed"
    return 1
  fi
}

install_semgrep() {
  log "Installing Semgrep"
  python3 -m pip install semgrep
  if [ $? -ne 0 ]; then
    log_error "Semgrep installation failed"
    return 1
  fi
}

install_oras() {
  log "Installing Oras"
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
}

install_jq() {
  log "Installing jq"
  sudo apt-get install jq -y
  if [ $? -ne 0 ]; then
    log_error "jq installation failed"
    return 1
  fi
}

install_ruby_restclient() {
  log "Installing Ruby rest-client"
  sudo gem install rest-client
  if [ $? -ne 0 ]; then
    log_error "rest-client installation failed"
    return 1
  fi
}

install_yq() {
  log "Installing yq"
  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
  if [ $? -ne 0 ]; then
    log_error "yq installation failed"
    return 1
  fi
  sudo chmod a+x /usr/local/bin/yq
}

install_parlay() {
  log "Installing Parlay"
  wget https://github.com/snyk/parlay/releases/latest/download/parlay_Linux_x86_64.tar.gz
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

install_chainloop_tools() {
  log_header "Installing Chainloop Tools"
  export PATH=/usr/local/bin:$PATH

  if [ -f /usr/local/bin/chainloop ]; then
    log "Skipping... Chainloop Tools already installed"
    return 0
  fi

  install_chainloop_cli_and_cosign
  install_syft
  install_semgrep
  install_oras
  install_jq
  install_yq
  install_parlay
}

###

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
  log "Adding Metadata files based on .chainloop.yml to attestation"
  script=`cat .chainloop.yml | yq eval '.attestation[] | "chainloop attestation add --name "  + .name + " --value " + .path + "; "'`
  eval $script
}

chainloop_attestation_init() {
  log "Initializing Chainloop Attestation"
  if [ -z "${CHAINLOOP_CONTRACT_REVISION+x}" ]; then
    chainloop attestation init -f
  else
    chainloop attestation init -f --contract-revision ${CHAINLOOP_CONTRACT_REVISION}
  fi
}

chainloop_attestation_status() {
  log "Checking Attestation Status"
  chainloop attestation status --full &> c8-status.txt
  cat c8-status.txt
}

chainloop_attestation_push() {
  log "Pushing Attestation"
  chainloop attestation push --key env://CHAINLOOP_SIGNING_KEY &> c8-push.txt
  cat c8-push.txt
}

chainloop_generate_github_summary() {
  log "Generating GitHub Summary"
  digest=`cat c8-push.txt| grep " Digest: " | awk -F\  '{print $3}'`
  echo -e "## Great job!\nYou are making SecOps and Compliance teams really happy. Keep up the good work!\n" >> $GITHUB_STEP_SUMMARY
  echo "**[Chainloop Trust Report](https://app.chainloop.dev/attestation/${digest})**" >> $GITHUB_STEP_SUMMARY 
  echo "\`\`\`" >> $GITHUB_STEP_SUMMARY 
  cat c8-status.txt >> $GITHUB_STEP_SUMMARY
  echo "\`\`\`" >> $GITHUB_STEP_SUMMARY 
}

chainloop_generate_github_summary_on_failure() {
  log "Generating GitHub Summary on Failure"
  echo "\`\`\`" >> $GITHUB_STEP_SUMMARY 
  if [ -f c8-push.txt ]; then
    cat c8-push.txt >> $GITHUB_STEP_SUMMARY
  fi
  if [ -f c8-status.txt ]; then
    cat c8-status.txt >> $GITHUB_STEP_SUMMARY
  fi
  echo "\`\`\`" >> $GITHUB_STEP_SUMMARY
}

chainloop_collect_logs_for_github_jobs() {
  log "Collecting logs for GitHub Jobs"
  # requires GH_TOKEN github.token 
  # https://docs.github.com/en/rest/actions/workflow-jobs?apiVersion=2022-11-28#download-job-logs-for-a-workflow-run
  mkdir -p reports/gh_logs
  gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs > reports/gh_logs/jobs.json
  for j in `cat reports/gh_logs/jobs.json | jq '.jobs[].id'` ; do
    gh api -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /repos/${GITHUB_REPOSITORY}/actions/jobs/${j}/logs > reports/gh_logs/${j}.log
  done
}

install_chainloop_labs_cli() {
  log "Installing Chainloop Labs CLI"
  mkdir -p reports
  branch=${1:-main}
  sudo curl -sfL https://raw.githubusercontent.com/chainloop-dev/labs/${branch}/tools/c8l -o /usr/local/bin/c8l
  if [ $? -ne 0 ]; then
    log_error "Failed to install labs CLI"
    return 1
  fi
  sudo chmod +x /usr/local/bin/c8l
}

install_labs_helpers() {
  log "Installing Chainloop Labs Helpers"
  branch=${1:-main}
  curl -sfL https://raw.githubusercontent.com/chainloop-dev/labs/${branch}/tools/src/lib/chainloop.sh -o ~/chainloop.sh
  if [ $? -ne 0 ]; then
    log_error "Failed to install labs helpers"
    return 1
  fi
}

install_chainloop_labs() {
  logs "Installing Chainloop Labs"
  branch=${1:-main}
  install_chainloop_labs_cli ${branch}
  install_labs_helpers ${branch}
}
