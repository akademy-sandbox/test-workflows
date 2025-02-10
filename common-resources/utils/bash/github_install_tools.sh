#!/bin/bash

# Function to install jq using package manager
install_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Installing jq..."
        sudo apt-get update -y && sudo apt-get install -y jq
        echo "jq installed successfully."
    else
        echo "jq is already installed."
    fi
}

# Function to install yq from GitHub releases
install_yq() {
    if ! command -v yq &> /dev/null; then
        echo "Installing yq..."
        wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        chmod +x /usr/local/bin/yq
        echo "yq installed successfully."
    else
        echo "yq is already installed."
    fi
}

# Function to install ansible and ansible playbook
install_ansible() {
    python3 --version        
    python3 -m pip install --user ansible
    python3 -m pip install --user pywinrm
    ~/.local/bin/ansible --version
    ~/.local/bin/ansible-playbook --version
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
}

# Function to install a given tool
install_tool() {
    local tool=$1
    case "$tool" in
        jq) install_jq ;;
        yq) install_yq ;;
        ansible) install_ansible ;;
        *)
            echo "Unknown tool: $tool"
            ;;
    esac
}

# Main function to process all tools
main() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 tool1 tool2 tool3 ..."
        exit 1
    fi

    for tool in "$@"; do
        install_tool "$tool"
    done
}

# Run main function with provided arguments
main "$@"
