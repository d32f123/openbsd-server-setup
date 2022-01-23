#!/bin/sh

ENVS="$(dirname $0)/../env.d"
. "$ENVS/general.sh" # for panic function

echo "${YELLOW}Downloading shell environment and utilities${NORM}"
doas pkg_add vim zsh zsh-syntax-highlighting bash curl git cmake gmake g++ wget coreutils || panic "Failed to download dependencies"

# set zsh as default shell
chsh -s "$(which zsh)"
echo "${YELLOW}Setting up shell environment${NORM}"

zsh -s <<'EOF' || panic "Failed to setup shell environment"
# setup shell
cd $(mktemp -d)
git clone --depth 1 https://github.com/d32f123/shell-environment.git

cd shell-environment && ./setup.sh || exit 1
source ~/.config/zsh/.zshrc

# build gitstatus, as it is not built for openbsd by default
cd $ZSH/custom/themes/powerlevel10k/gitstatus
bash build -w
EOF
