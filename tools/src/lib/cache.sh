
# chainloop_bin_cache_in_dir - it takes a path and copy there the CHAINLOOP_BIN_PATH
chainloop_bin_cache_in_dir() {
  mkdir -p $1
  cp -r $CHAINLOOP_BIN_PATH/* $1
}

# chainloop_recreate_env_from_cache - it takes the path to the file in the format .env_NAME and export env variable NAME=`what is in the file`
# for instance .c8l_cache/.env_chainloop_attestation_id end exports variable CHAINLOOP_ATTESTATION_ID with the value from the file
# or .c8l_cache/.env_chainloop_signing_key_path end exports variable CHAINLOOP_SIGNING_KEY_PATH with the value from the file
# it validates the file exists and is not empty and the file name is in the format .env_NAME
chainloop_recreate_env_from_file() {
  path=$1
  # if the path is empty or does not exist, return
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    log_error "chainloop_recreate_env_from_file: path $path does not exist"
    return 1
  fi
  file=$(basename $path)
  if [[ $file =~ ^\.env_.*$ ]]; then
    export $(echo $file | sed 's/\.env_//')=$(cat $path)
    echo export $(echo $file | sed 's/\.env_//')=$(cat $path)
  else
    log_error "File $file is not in the format .env_NAME"
    return 1
  fi
}

# chainloop_save_env_to_file - it takes the name of the env variable and saves it to the file in the format .env_NAME
chainloop_save_env_to_file() {
  name=$1
  dir=$2
  if [ -z "${name}" ]; then
    log_error "Name is not set"
    return 1
  fi
  # if $dir is empty or directory #$dir does not exist, return
  if [ -z "${dir}" ] || [ ! -d "${dir}" ]; then
    log_error "Directory $dir does not exist"
    return 1
  fi
  if [ -z "${!name}" ]; then
    log_error "Variable $name is not set"
    return 1
  fi
  echo "${!name}" >$dir/.env_${name}
}

# chainloop_save_env_to_cache - it takes the cache directory which is the first parameter and then the list of env variables which are saved to the cache
# it validates directory exists and is a directory
chainloop_save_env_to_cache() {
  cache_dir=$1
  if [ -z "${cache_dir}" ] || [ ! -d "${cache_dir}" ]; then
    log_error "Cache directory $cache_dir does not exist"
    return 1
  fi
  for name in "${@:2}"; do
    chainloop_save_env_to_file $name $cache_dir
  done
}

# chainloop_restore_env_all_from_cache - it finds all the .env_NAME files in the directory specified as first argument and exports the env variables
# it validates if the directory exists and is a directory
chainloop_restore_env_all_from_cache() {
  cache_dir=$1
  if [ -z "${cache_dir}" ] || [ ! -d "${cache_dir}" ]; then
    log_error "Cache directory $cache_dir does not exist"
    return 1
  fi
  for file in $cache_dir/.env_*; do
    chainloop_recreate_env_from_file $file
  done
}

# chainloop_restore_all_from_cache - it restores the env variables and the tools from the cache
# it takes the cache directory as the first parameter and validates if it exists and is a directory
chainloop_restore_all_from_cache() {
  cache_dir=$1
  if [ -z "${cache_dir}" ] || [ ! -d "${cache_dir}" ]; then
    log_error "Cache directory $cache_dir does not exist"
    return 1
  fi
  chainloop_restore_env_all_from_cache $cache_dir
  chainloop_bin_install $cache_dir/*
}
