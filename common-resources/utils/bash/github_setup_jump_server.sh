#!/bin/bash

# Load environment variables from env.sh
if [[ -f ".env" ]]; then
    export $(grep -v '^#' .env | xargs)
    echo "Environment variables loaded successfully."
    echo "JUMP_SERVER_HOST: $JUMP_SERVER_HOST"
    ls -l .env
else
    echo "Error: env.sh file not found."
    exit 1
fi
# Create Service User and Service password variables
export SERVICE_USER_NAME="$2"
export SERVICE_USER_PASSWORD="$3"
export JUMP_SERVER_HOST="$7"
export JUMP_SERVER_HOME_DIR="$8"

# Function to create and clean home directory on the jump server
create_clean_home_dir() {
    echo "Creating and cleaning home directory on the jump server..."
    # echo vars used
    echo "JUMP_SERVER_HOST: $JUMP_SERVER_HOST"
    echo "JUMP_SERVER_HOME_DIR: $JUMP_SERVER_HOME_DIR"
    echo "SERVICE_USER_NAME: $SERVICE_USER_NAME"
    sshpass -p "$SERVICE_USER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        "$SERVICE_USER_NAME@$JUMP_SERVER_HOST" "mkdir -p $JUMP_SERVER_HOME_DIR && rm -rf $JUMP_SERVER_HOME_DIR/*"
    echo "Home directory cleaned and prepared."
}

# Function to copy scripts from GitHub runner to the jump server
copy_scripts_to_jump_server() {
    echo "Copying scripts from GitHub runner to the jump server..."
    app_dir="$4"-"$5"
    # convert app_dir to lowercase
    app_dir=$(echo "$app_dir" | tr '[:upper:]' '[:lower:]')

    echo "APP_DIR: $app_dir"
    # append app_dir to .env file
    echo "APP_DIR=$app_dir" >> .env
    echo "AUTOMATION_TASK=$4" >> .env
    sshpass -p "$SERVICE_USER_PASSWORD" scp -o StrictHostKeyChecking=no -r "$GITHUB_WORKSPACE" \
        "$SERVICE_USER_NAME@$JUMP_SERVER_HOST:$JUMP_SERVER_HOME_DIR/$app_dir"
    echo "Scripts copied successfully."
}

# Function to clean up after script execution
clean_after_execution() {
    echo "Cleaning up installation files from the jump server..."
    sshpass -p "$SERVICE_USER_PASSWORD" ssh -o StrictHostKeyChecking=no \
        "$SERVICE_USER_NAME@$JUMP_SERVER_HOST" "rm -rf $JUMP_SERVER_HOME_DIR"
    echo "Cleanup complete."
}

# function install
install() {
    echo "Installing file-cleaner-utility on $TARGET_SERVER_HOST which is a $TARGET_SERVER_HOST environment"
    app_dir="$4"-"$5"
    # convert app_dir to lowercase
    app_dir=$(echo "$app_dir" | tr '[:upper:]' '[:lower:]')
    echo "APP_DIR: $app_dir"
    # append app_dir to .env file
    echo "APP_DIR=$app_dir" >> .env
    echo "AUTOMATION_TASK=$4" >> .env
    sshpass -p $SERVICE_USER_PASSWORD ssh -o StrictHostKeyChecking=no \
        $SERVICE_USER_NAME@$JUMP_SERVER_HOST \
        "cd $JUMP_SERVER_HOME_DIR/$app_dir; ls -la; pwd; chmod +x $4/scripts/main.sh; $4/scripts/main.sh $3"
    echo "Installation complete..."
}

# Function to execute the requested step
run_step() {
    case "$1" in
        create_home)
            create_clean_home_dir
            ;;
        copy_scripts)
            create_clean_home_dir
            copy_scripts_to_jump_server $1 $2 $3 $4 $5 $6 $7 $8
            ;;
        clean_up)
            clean_after_execution
            ;;
        install)
            create_clean_home_dir
            copy_scripts_to_jump_server $1 $2 $3 $4 $5 $6 $7 $8
            install $1 $2 $3 $4 $5 $6 $7 $8
            ;;    
        *)
            echo "Usage: $0 {create_home|copy_scripts|install|clean_up}"
            exit 1
            ;;
    esac
}
# validate environment variables
#validate_env_vars

# Run the requested step

run_step "$1" "$2" "$3" "$4" "$5" "$6"
