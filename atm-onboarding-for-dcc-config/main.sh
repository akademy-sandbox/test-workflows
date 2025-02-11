#!/bin/bash

# Load environment variables from env.sh
if [[ -f ".env" ]]; then
    export $(cat .env | xargs)
    cat .env
else
    echo "Error: env.sh file not found."
    exit 1
fi

ANSIBLE_ROLE="${ACTION}-${AUTOMATION_TASK}"
ANSIBLE_PASSWORD="$1"


echo "Running ansible playbook with role $ANSIBLE_ROLE"
#sudo docker run --rm -v $(pwd):$(pwd) dockerhub.cuscalad.com/ci-cd/ansible-cmd:2.0.0 bash -o pipefail -c "set -e; cd $(pwd);ls -l ; export ANSIBLE_CONFIG="$(pwd)/common-resources/ansible/ansible.cfg"; ansible-playbook -vvv ./common-resources/ansible/main.yml -e "@${AUTOMATION_TASK}/configs/ansible_task_parameters.yml" -i ./common-resources/ansible/hosts --extra-vars 'ansible_user=${ANSIBLE_USER} ansible_ssh_pass=${ANSIBLE_PASSWORD} target_servers=${TARGET_HOSTS}.cuscalad.com environment=${ENVIRONMENT} automation_task=${AUTOMATION_TASK} automation_role=${ANSIBLE_ROLE} script_source_path=${WORKING_DIR}/${APP_DIR} db_host=${DB_HOST} db_name=${DB_NAME}'"

export ANSIBLE_CONFIG="$(pwd)/common-resources/ansible/ansible.cfg"

ansible-playbook -vvv ./common-resources/ansible/main.yml -e "@${AUTOMATION_TASK}/configs/ansible_task_parameters.yml" -i ./common-resources/ansible/hosts --extra-vars 'ansible_user=${ANSIBLE_USER} ansible_ssh_pass=${ANSIBLE_PASSWORD} target_servers=${TARGET_HOSTS}.cuscalad.com environment=${ENVIRONMENT} automation_task=${AUTOMATION_TASK} automation_role=${ANSIBLE_ROLE} script_source_path=${WORKING_DIR}/${APP_DIR} db_host=${DB_HOST} db_name=${DB_NAME}'




