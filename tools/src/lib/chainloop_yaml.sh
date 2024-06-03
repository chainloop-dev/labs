chainloop_attestation_add_from_yaml() {
  export ATTESTATION_NAME=$1
  if [ -z "${ATTESTATION_NAME}" ]; then
    export ATTESTATION_NAME="attestation"
  fi
  log "Adding Metadata files based on .chainloop.yml"
  script=$(cat .chainloop.yml | yq eval '.[strenv(ATTESTATION_NAME)][] | "chainloop attestation add --name "  + .name + " --value " + .path + " --remote-state --attestation-id ${CHAINLOOP_ATTESTATION_ID} 2>&1; "')
  log $script
  eval $script
}