#!/usr/local/bin/zsh

# set zsh as default shell
chsh -s "$(which zsh)"

# setup shell
git clone --depth 1 https://github.com/d32f123/shell-environment.git
./shell-environment/setup.sh

source ~/.config/zsh/.zshrc

# build gitstatus, as it is not built for openbsd by default
pushd $ZSH/custom/themes/powerlevel10k/gitstatus
bash build -w
popd

# tmux-plugin-sysstat CPU and MEM are failing on OpenBSD, patch the issues
