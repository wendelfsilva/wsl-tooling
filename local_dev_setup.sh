#!/bin/bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034
# Author: Wendel Silva

ZSH_ENABLED=${ZSH_ENABLED:-'yes'}
ZSH_THEME=${ZSH_THEME:-'robbyrussell'}
DOCKER_ENABLED=${DOCKER_ENABLED:-'no'}
PYENV_ENABLED=${PYENV_ENABLED:-'yes'}
PYENV_PYTHON_VERSION=${PYENV_PYTHON_VERSION:-'3:latest'}
NVM_ENABLED=${NVM_ENABLED:-'yes'}
NVM_NODE_VERSION=${NVM_NODE_VERSION:-'latest'}

# Terminal colors
NC="\033[0m" # No Color
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
BROWN="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
GRAY="\033[0;37m"

# Function to print colorized messages
print_message() {
    local message=$1
    local color=$2
    echo -e "${color:-${NC}}${message}${NC}"
}

# Function to check if the script is running as sudo
check_sudo() {
    if (($(id -u) == 0)); then
        print_message "Please run the script without sudo and wait for the sudo password to be requested" "${RED}"
        exit 0
    fi

    if ! sudo echo "Starting local dev setup for ${USER}..."; then
        print_message "Aborted" "${RED}"
        exit 0
    fi
}

# Function to create wsl.conf
create_wsl_conf() {
    if [ ! -f "/etc/wsl.conf" ]; then
        print_message "Creating /etc/wsl.conf" "${GREEN}"
        {
            echo "[boot]"
            echo "systemd = true"
        } | sudo tee /etc/wsl.conf >/dev/null
    fi
}

# Function to set user profile preferences
create_user_profile_folder() {
    USER_PROFILE="${HOME}/.bashrc"
    if [[ "${SHELL}" == *"zsh"* ]]; then
        USER_PROFILE="${HOME}/.zshrc"
    fi

    USER_PROFILE_DIR="${HOME}/.profile.d"
    if [ ! -d "${USER_PROFILE_DIR}" ]; then
        print_message "Creating ${USER_PROFILE_DIR}" "${GREEN}"
        mkdir -m 0755 "${USER_PROFILE_DIR}"
    fi
}

# Function to install system dependencies
install_system_dependencies() {
    print_message "Installing system dependencies..." "${GREEN}"
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt install -y -f \
        git \
        build-essential \
        python3-dev \
        python3-tk \
        tk-dev \
        zlib1g-dev \
        libssl-dev \
        libbz2-dev \
        libffi-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncurses-dev \
        liblzma-dev
}

# Function to install Docker and Docker Compose
install_docker() {
    if [[ "${DOCKER_ENABLED}" == "yes" ]]; then
        if [ -f "/usr/bin/docker" ]; then
            print_message "docker is already installed... Done" "${BLUE}"
        else
            # Add Docker's official GPG key:
            sudo apt-get update -y
            sudo apt-get install -y -f \
                ca-certificates \
                curl \
                gnupg
            sudo install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            sudo chmod a+r /etc/apt/keyrings/docker.gpg

            # Add the repository to Apt sources:
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" |
                sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
            sudo apt-get update -y
            sudo apt-get install -y -f \
                docker-ce \
                docker-ce-cli \
                containerd.io \
                docker-buildx-plugin \
                docker-compose-plugin

            # https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user
            # Create docker group and associate to the logged user
            sudo groupadd docker
            sudo usermod -aG docker "${USER}"

            # Docker entry in user profile
            print_message "Creating docker entry in ${USER_PROFILE_DIR}" "${GREEN}"
            {
                echo "export DOCKER_HOST=\"unix:///var/run/docker.sock\""
                echo "export DOCKER_TLS_VERIFY=\"1\""
                echo "export DOCKER_CERT_PATH=\"\$HOME/.docker/certs\""
            } >"${USER_PROFILE_DIR}/docker"
        fi
    fi
}

# Function to install pyenv
install_pyenv() {
    if [[ "${PYENV_ENABLED}" == "yes" ]]; then
        if [ -f "${HOME}/.pyenv/bin/pyenv" ]; then
            echo "pyenv is already installed... Done"
        else
            echo "Installing pyenv"
            curl https://pyenv.run | bash

            print_message "Creating pyenv entry in ${USER_PROFILE_DIR}" "${GREEN}"
            {
                echo "export PYENV_ROOT=\"\$HOME/.pyenv\""
                echo "export PATH=\$(echo \$PATH | sed -E \"s@([^:]*\.pyenv/[^:]*(:|$))@@g\")"
                echo "[[ -d \$PYENV_ROOT/bin ]] && export PATH=\"\$PYENV_ROOT/bin:\$PATH\""
                echo "eval \"\$(pyenv init -)\""
            } >"${USER_PROFILE_DIR}/pyenv"
        fi
    fi
}

# Function to install Python using pyenv
install_python_with_pyenv() {
    if [ ! -f "${HOME}/.pyenv/bin/pyenv" ]; then
        print_message "pyenv not found, skipping installation" "${RED}"
    else
        . "${USER_PROFILE_DIR}/pyenv"

        if [[ "$(pyenv versions)" == *"${PYENV_PYTHON_VERSION}"* ]]; then
            print_message "python ${PYENV_PYTHON_VERSION} is already installed... Done" "${BLUE}"
        else
            print_message "Installing python ${PYENV_PYTHON_VERSION}" "${GREEN}"
            pyenv install "${PYENV_PYTHON_VERSION}"
        fi
    fi
}

# Function to install nvm
install_nvm() {
    if [[ "${NVM_ENABLED}" == "yes" ]]; then
        if [ -f "${HOME}/.nvm/nvm.sh" ]; then
            print_message "nvm is already installed... Done" "${BLUE}"
        else
            if [ ! -d "${HOME}/.nvm" ]; then
                git clone https://github.com/nvm-sh/nvm.git "${HOME}/.nvm"
            fi

            print_message "Getting latest nvm version" "${GREEN}"
            NVM_VERSION=$(git -C "${HOME}/.nvm" tag --list --sort=version:refname | tail -1)

            print_message "Setting nvm version to ${NVM_VERSION}" "${GREEN}"
            git checkout --quiet "${NVM_VERSION}"

            print_message "Creating nvm entry in ${USER_PROFILE_DIR}" "${GREEN}"
            {
                echo "export NVM_DIR=\"\$HOME/.nvm\""
                echo "[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\" # This loads nvm"
                echo "[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"  # This loads nvm bash_completion"
            } >"${USER_PROFILE_DIR}/nvm"
        fi
    fi
}

# Function to install npm using nvm
install_npm_with_nvm() {
    if [ ! -f "${HOME}/.nvm/nvm.sh" ]; then
        print_message "nvm not found, skipping installation" "${RED}"
    else
        . "${USER_PROFILE_DIR}/nvm"

        if [[ "${NVM_NODE_VERSION}" == "latest" ]]; then
            NVM_NODE_VERSION=$(nvm version-remote --lts | tr -d v)
        fi

        if [[ "$(nvm ls "${NVM_NODE_VERSION}")" == *"${NVM_NODE_VERSION}"* ]]; then
            print_message "npm ${NVM_NODE_VERSION} is already installed... Done" "${BLUE}"
        else
            print_message "Installing npm ${NVM_NODE_VERSION}" "${GREEN}"
            nvm install "${NVM_NODE_VERSION}"
        fi
    fi
}

# Function to install zsh
install_zsh() {
    if [[ "${ZSH_ENABLED}" == "yes" ]]; then

        if [[ "${SHELL}" == *"zsh"* || -d "${HOME}/.oh-my-zsh" ]]; then
            print_message "zsh is already installed... Done" "${BLUE}"
        else
            print_message "Installing apt ZSH..." "${GREEN}"
            sudo apt install -y zsh
            chsh -s "$(which zsh)"

            print_message "Installing zsh..." "${GREEN}"
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi

        USER_PROFILE="${HOME}/.zshrc"

        if [[ "$(cat "${USER_PROFILE}")" == *"ZSH_THEME=\"${ZSH_THEME}\""* ]]; then
            print_message "zsh theme ${ZSH_THEME} is already installed... Done" "${BLUE}"
        else
            print_message "Installing ${ZSH_THEME} as zsh theme" "${GREEN}"
            sed -i "s/^ZSH_THEME=.\+$/ZSH_THEME=\"${ZSH_THEME}\"/g" "${USER_PROFILE}"
        fi
    fi
}

# Include all files in ${USER_PROFILE_DIR}
update_user_profile() {
    USER_PROFILE_INCLUDE="for f in ${USER_PROFILE_DIR}/*; do source \$f; done"
    if [[ "$(cat "${USER_PROFILE}")" != *"${USER_PROFILE_INCLUDE}"* ]]; then
        {
            echo
            echo "# Include all files in ${USER_PROFILE_DIR}"
            echo "$USER_PROFILE_INCLUDE"
        } >>"${USER_PROFILE}"
    fi
}

# Main function
main() {
    check_sudo
    create_wsl_conf
    create_user_profile_folder
    install_system_dependencies
    install_docker
    install_pyenv
    install_python_with_pyenv
    install_nvm
    install_npm_with_nvm
    install_zsh
    update_user_profile
}

# Run the main function
main
print_message "\nAll done, ensure to re-open your terminal to get all changes." "${GREEN}"
