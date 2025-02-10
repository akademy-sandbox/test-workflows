#!/bin/bash
automation_task="$1"
environment="$2"

# Function to generate .env file from input_parameters.yml
load_inventory() {
    python3 ${LOAD_INVENTORY_UTIL_PATH} --automation_task_name ${AUTOMATION_TASK} --environment ${ENVIRONMENT} --data_center ${DATA_CENTRE} --environment_type ${ENVIRONMENT_TYPE} --inventory_file_path "${INVENTORY_FILE_PATH}"
    echo "Input Parameters has been parsed and loaded to .env file successfully."
    # Check if .env file exists
    if [ -f ".env" ]; then
        echo "Environment variables loaded to .env file successfully."
    else
        echo "Error: .env file not found. Please debug the execution of load_default_inputs.py."
        exit 1
    fi
}

# Function to generate .env file from input_parameters.yml
load_global_configs() {
    python3 ${LOAD_GLOBAL_CONFIGS_UTIL_PATH} --environment ${ENVIRONMENT} --global_config_file_path "${GLOBAL_CONFIGS_PATH}"
    echo "Input Parameters has been parsed and loaded to .env file successfully."
    # Check if .env file exists
    if [ -f ".env" ]; then
        echo "Environment variables loaded to .env file successfully."
    else
        echo "Error: .env file not found. Please debug the execution of load_default_inputs.py."
        exit 1
    fi
}

# Function to create cache keys
load_dot_env_file_cache_key() {
    random_string=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo '')
    dot_env_file_cache_key="cache-key-${random_string}"
    # convert env_cache_key to uppder case and append to .env file
    echo "DOT_ENV_FILE_CACHE_KEY=${dot_env_file_cache_key}" >> .env
}

# Function to export environment variables from .env file
export_env_variables() {
    set -o allexport
    export $(cat .env | xargs)
    set +o allexport
}

load_inventory
load_global_configs
load_dot_env_file_cache_key
export_env_variables





