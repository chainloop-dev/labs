validate_env

uuid="${args['uuid']}"

# if sha is empty then read from stdin
if [ -z "$uuid" ]; then
  l "Enter UUID of the workflow to get: "
  read -r uuid
fi

# validate UUID format
if [[ ! "$uuid" =~ ^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$ ]]; then
  log_error "Invalid UUID format: $uuid"
  return 1
fi

outmode=json

r=$(chainloop wf list --full -o json | jq --arg id "$uuid" '.[] | select(.id == $id)')
contractID=$(echo "$r" | jq -r '.contractID')

echo $r | jq

l "\n\nContract"
chainloop wf contract  describe --id "${contractID}" -o table

l "\n\nWorkflow Robot Accounts"
chainloop wf ra list --workflow "${uuid}" -o $outmode

l "\n\nWorkflow Runs"
chainloop wf workflow-run list --workflow "${uuid}" -o table