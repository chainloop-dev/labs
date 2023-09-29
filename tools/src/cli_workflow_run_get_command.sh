validate_env

uuid="${args['uuid']}"

# if sha is empty then read from stdin
if [ -z "$uuid" ]; then
  l "Enter UUID of the workflow run to get: "
  read -r uuid
fi

# validate UUID format
if [[ ! "$uuid" =~ ^[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}$ ]]; then
  log_error "Invalid UUID format: $uuid"
  return 1
fi

chainloop workflow run describe --id "${uuid}" -o statement