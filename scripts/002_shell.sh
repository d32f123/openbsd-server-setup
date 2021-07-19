#!/usr/local/bin/zsh

# set zsh as default shell
chsh -s "$(which zsh)"

# setup shell
pushd
git clone --depth 1 https://github.com/d32f123/shell-environment.git

cd shell-environment && ./setup.sh
cd -
rm -rf shell-environment
popd

source ~/.config/zsh/.zshrc

# build gitstatus, as it is not built for openbsd by default
pushd $ZSH/custom/themes/powerlevel10k/gitstatus
bash build -w
popd
