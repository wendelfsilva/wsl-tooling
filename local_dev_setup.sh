#!/bin/bash
# shellcheck source=/dev/null
# shellcheck disable=SC2034
# Author: Wendel Silva
# Description: This script will install all dependencies to setup a local development environment on WSL2

set -e

ZSH_ENABLED=${ZSH_ENABLED:-'yes'}
ZSH_THEME=${ZSH_THEME:-'robbyrussell'}
DOCKER_ENABLED=${DOCKER_ENABLED:-'no'}
DIRENV_ENABLED=${DOCKER_ENABLED:-'yes'}
PYENV_ENABLED=${PYENV_ENABLED:-'yes'}
PYENV_PYTHON_VERSION=${PYENV_PYTHON_VERSION:-'3:latest'}
NVM_ENABLED=${NVM_ENABLED:-'yes'}
NVM_NODE_VERSION=${NVM_NODE_VERSION:-'latest'}

# Terminal colors
NC="\033[0m"
BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
ORANGE="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
GRAY="\033[0;37m"

DEFAULT=${BLUE}
SUCCESS=${GREEN}
WARNING=${ORANGE}
ERROR=${RED}

# Function to print colorized messages
print_message() {
	local message=$1
	local color=$2
	echo -e "${color:-${DEFAULT}}${message}${NC}"
}

# Function to check if the script is running as sudo
check_sudo() {
	if (($(id -u) == 0)); then
		print_message "Please run the script without sudo and wait for the sudo password to be requested" "${ERROR}"
		exit 0
	fi

	if ! sudo echo "Starting local dev setup for ${USER}..."; then
		print_message "Aborted" "${ERROR}"
		exit 0
	fi
}

# Function to install zsh
install_zsh() {
	if [[ "${ZSH_ENABLED}" == "yes" ]]; then

		if [[ -d "${HOME}/.oh-my-zsh" ]]; then
			print_message "zsh is already installed... Done" "${SUCCESS}"
		else
			print_message "Installing ZSH"
			sudo apt install -y zsh
			sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
		fi

		if [[ ! "${SHELL}" == *"zsh"* ]]; then
			print_message "Changing user shell to zsh"
			sudo chsh "${USER}" -s "$(which zsh)"
   			export SHELL=$(which zsh)
		fi

		USER_PROFILE="${HOME}/.zshrc"
		if [[ "$(cat "${USER_PROFILE}")" == *"ZSH_THEME=\"${ZSH_THEME}\""* ]]; then
			print_message "zsh theme ${ZSH_THEME} is already installed... Done" "${SUCCESS}"
		else
			print_message "Installing ${ZSH_THEME} as zsh theme"
			sed -i "s/^ZSH_THEME=.\+$/ZSH_THEME=\"${ZSH_THEME}\"/g" "${USER_PROFILE}"
		fi

  		print_message "Sourcing Zsh configuration to apply changes"
		source "${USER_PROFILE}"

		print_message "zsh installed... Done" "${SUCCESS}"
	fi
}

# Function to create wsl.conf
create_wsl_conf() {
	if [ ! -f "/etc/wsl.conf" ]; then
		print_message "Creating /etc/wsl.conf"
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
		print_message "Creating ${USER_PROFILE_DIR}"
		mkdir -m 0755 "${USER_PROFILE_DIR}"
	fi
}

# Function to install system dependencies
install_system_dependencies() {
	print_message "Installing system dependencies"
	sudo apt update -y
	sudo apt upgrade -y
	sudo apt install -y -f \
		git \
		build-essential \
		python3-dev \
		python3-tk \
		python3-twisted \
		python3-distutils \
		python3-setuptools \
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
		if [ -x "$(command -v docker)" ]; then
			print_message "docker is already installed... Done" "${SUCCESS}"
		else
			print_message "Installing docker"

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

			print_message "Adding ${USER} to docker group"
			sudo groupadd docker
			sudo usermod -aG docker "${USER}"

			# Docker entry in user profile
			print_message "Creating docker entry in ${USER_PROFILE_DIR}"
			{
				echo "export DOCKER_HOST=\"unix:///var/run/docker.sock\""
				echo "export DOCKER_TLS_VERIFY=\"1\""
				echo "export DOCKER_CERT_PATH=\"\$HOME/.docker/certs\""
			} >"${USER_PROFILE_DIR}/docker"

			print_message "docker installed... Done" "${SUCCESS}"
		fi
	fi
}

# Function to install direnv
install_direnv() {
	if [[ "${DIRENV_ENABLED}" == "yes" ]]; then
		if [ -x "$(command -v direnv)" ]; then
			print_message "direnv is already installed... Done" "${SUCCESS}"
		else
			print_message "Installing direnv"

			sudo apt-get install -y -f \
				direnv

			# Direnv entry in user profile
			print_message "Creating direnv entry in ${USER_PROFILE_DIR}"
			{
				echo "eval \"\$(direnv hook zsh)\""
			} >"${USER_PROFILE_DIR}/direnv"

			print_message "direnv installed... Done" "${SUCCESS}"
		fi
	fi
}

# Function to install pyenv
install_pyenv() {
	if [[ "${PYENV_ENABLED}" == "yes" ]]; then
		if [ -f "${HOME}/.pyenv/bin/pyenv" ]; then
			print_message "pyenv is already installed... Done" "${SUCCESS}"
		else
			print_message "Installing pyenv" "${BLUE}"
			curl https://pyenv.run | bash

			print_message "Creating pyenv entry in ${USER_PROFILE_DIR}"
			{
				echo "export PYENV_ROOT=\"\$HOME/.pyenv\""
				echo "export PATH=\$(echo \$PATH | sed -E \"s@([^:]*\.pyenv/[^:]*(:|$))@@g\")"
				echo "[[ -d \$PYENV_ROOT/bin ]] && export PATH=\"\$PYENV_ROOT/bin:\$PATH\""
				echo "eval \"\$(pyenv init -)\""
			} >"${USER_PROFILE_DIR}/pyenv"

			print_message "pyenv installed... Done" "${SUCCESS}"
		fi
	fi
}

# Function to install Python using pyenv
install_python_with_pyenv() {
	if [ ! -f "${HOME}/.pyenv/bin/pyenv" ]; then
		print_message "pyenv not found, skipping installation" "${WARNING}"
	else
		. "${USER_PROFILE_DIR}/pyenv"

		if [[ "$(pyenv versions)" == *"${PYENV_PYTHON_VERSION}"* ]]; then
			print_message "python ${PYENV_PYTHON_VERSION} is already installed... Done" "${SUCCESS}"
		else
			print_message "Installing python ${PYENV_PYTHON_VERSION}"
			pyenv install "${PYENV_PYTHON_VERSION}"

			print_message "python ${PYENV_PYTHON_VERSION} installed... Done" "${SUCCESS}"
		fi
	fi
}

# Function to install nvm
install_nvm() {
	if [[ "${NVM_ENABLED}" != "no" ]]; then
		if [ -f "${HOME}/.nvm/nvm.sh" ]; then
			print_message "nvm is already installed... Done" "${SUCCESS}"
		else
			if [ ! -d "${HOME}/.nvm" ]; then
				git clone https://github.com/nvm-sh/nvm.git "${HOME}/.nvm"
			fi

			print_message "Getting latest nvm version"
			NVM_VERSION=$(git -C "${HOME}/.nvm" tag --list --sort=version:refname | tail -1)

			print_message "Setting nvm version to ${NVM_VERSION}"
			git -C "${HOME}/.nvm" checkout --quiet "${NVM_VERSION}"

			print_message "Creating nvm entry in ${USER_PROFILE_DIR}"
			cat <<-EOF >"${USER_PROFILE_DIR}/nvm"
				export NVM_DIR="\$HOME/.nvm"
				[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh" # This loads nvm
				[ -s "\$NVM_DIR/bash_completion" ] && \. "\$NVM_DIR/bash_completion"  # This loads nvm bash_completion

				# place this after nvm initialization!
				autoload -U add-zsh-hook

				load-nvmrc() {
					local nvmrc_path
					nvmrc_path="\$(nvm_find_nvmrc)"

					if [ -n "\$nvmrc_path" ]; then
						local nvmrc_node_version
						nvmrc_node_version=\$(nvm version "\$(cat "\${nvmrc_path}")")

						if [ "\$nvmrc_node_version" = "N/A" ]; then
							nvm install
						elif [ "\$nvmrc_node_version" != "\$(nvm version)" ]; then
							nvm use
						fi
					elif [ -n "\$(PWD=\$OLDPWD nvm_find_nvmrc)" ] && [ "\$(nvm version)" != "\$(nvm version default)" ]; then
						echo "Reverting to nvm default version"
						nvm use default
					fi
				}

				add-zsh-hook chpwd load-nvmrc
				load-nvmrc
			EOF

			print_message "nvm installed... Done" "${SUCCESS}"
		fi
	fi
}

# Function to install npm using nvm
install_npm_with_nvm() {
	if [ ! -f "${HOME}/.nvm/nvm.sh" ]; then
		print_message "nvm not found, skipping installation" "${WARNING}"
	else
		. "${USER_PROFILE_DIR}/nvm"

		if [[ "${NVM_NODE_VERSION}" == "latest" ]]; then
			NVM_NODE_VERSION=$(nvm version-remote --lts | tr -d v)
		fi

		if [[ "$(nvm ls "${NVM_NODE_VERSION}")" == *"${NVM_NODE_VERSION}"* ]]; then
			print_message "npm ${NVM_NODE_VERSION} is already installed... Done" "${SUCCESS}"
		else
			print_message "Installing npm ${NVM_NODE_VERSION}"
			nvm install "${NVM_NODE_VERSION}"

			print_message "npm ${NVM_NODE_VERSION} installed... Done" "${SUCCESS}"
		fi
	fi
}

# Include all files in ${USER_PROFILE_DIR}
update_user_profile() {
	USER_PROFILE_INCLUDE="for f in ${USER_PROFILE_DIR}/*; do source \$f; done"
	if [[ "$(cat "${USER_PROFILE}")" == *"${USER_PROFILE_INCLUDE}"* ]]; then
		print_message "${USER_PROFILE_DIR} is already set... Done" "${SUCCESS}"
	else
		print_message "Setting ${USER_PROFILE_DIR} to ${USER_PROFILE}"

		{
			echo
			echo "# Include all files in ${USER_PROFILE_DIR}"
			echo "$USER_PROFILE_INCLUDE"
		} >>"${USER_PROFILE}"

		print_message "${USER_PROFILE_DIR} set... Done" "${SUCCESS}"
	fi
}

# Main function
main() {
	check_sudo
	install_zsh

	if [[ "${SHELL}" != *"zsh"* ]]; then
		print_message "Restarting script in Zsh..." "${WARNING}"
		exec zsh -c "$0"
	fi
 
	create_wsl_conf
	create_user_profile_folder
	install_system_dependencies
	install_docker
	install_direnv
	install_pyenv
	install_python_with_pyenv
	install_nvm
	install_npm_with_nvm
	update_user_profile
}

# Run the main function
main
print_message "\nAll done, ensure to re-open your terminal to get all changes." "${WARNING}"
