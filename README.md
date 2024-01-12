# wsl-tooling

## Installation
To set up the WSL (Windows Subsystem for Linux) development environment, you can use the following one-liner:

```shell
curl -sSL https://raw.githubusercontent.com/wendelfsilva/wsl-tooling/main/local_dev_setup.sh | bash
```

To customize the installation with specific env values, follow this example:

```shell
curl -sSL https://raw.githubusercontent.com/wendelfsilva/wsl-tooling/main/local_dev_setup.sh | \
PYENV_PYTHON_VERSION=3.11 NVM_NODE_VERSION=12.22 bash
```

## Available Envs

- *ZSH_THEME*: The theme for the Zsh shell (default: robbyrussell).
- *DOCKER_ENABLED*: Enable Docker integration (default: no).
- *PYENV_ENABLED*: Enable Pyenv for Python version management (default: yes).
- *PYENV_PYTHON_VERSION*: Specify the Python version for Pyenv (default: latest).
- *NVM_ENABLED*: Enable NVM (Node Version Manager) for Node.js version management (default: yes).
- *NVM_NODE_VERSION*: Specify the Node.js version for NVM (default: latest).
- *Feel free to customize these variables based on your preferences and project requirements.
