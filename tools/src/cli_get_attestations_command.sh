validate_env

sha="${args['sha']}"

# if sha is empty then read from stdin
if [ -z "$sha" ]; then
  l "Enter sha256 of the artifact to download: "
  read -r sha
fi

if [[ "$sha" == *:* ]]; then
  sha="${artifact##*:}"
fi

# validate sha256 format
if [[ ! "$sha" =~ ^[a-f0-9]{64}$ ]]; then
  log_error "Invalid sha256 format: $sha"
  return 1
fi

l "All attestations for $sha"
get_attestations_uuids $sha
# grpcurl -H "authorization: Bearer $TOKEN" api.cp.chainloop.dev:443  controlplane.v1.WorkflowRunService.List
# grpcurl -H "authorization: Bearer $TOKEN" api.cp.chainloop.dev:443 list 
# grpcui -H "authorization: Bearer $TOKEN" api.cp.chainloop.dev:443 
