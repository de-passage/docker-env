FROM archlinux/archlinux

RUN pacman -Syu --needed --noconfirm base-devel bash git neovim unzip tmux fzf zsh git-delta jq starship curl ripgrep fd bat

ARG home_dir=/home/dev
ARG workspace="${home_dir}/workspace"
ARG config="${home_dir}/.config"
ARG dotfiles="${config}/dotfiles"

RUN useradd -d "${home_dir}" -m dev -s /usr/sbin/zsh && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev
WORKDIR "${home_dir}"

RUN mkdir -p "${workspace}" && mkdir -p "${config}" && mkdir "${config}/tmux"

RUN git clone --bare https://github.com/de-passage/dotfiles "${dotfiles}" && \
    git --work-tree="${home_dir}" --git-dir="${dotfiles}" checkout wsl_zsh --force

RUN git clone https://github.com/tmux-plugins/tpm "${home_dir}/.tmux/plugins/tpm" && \
    echo <<EOF >>  "${home_dir}/.tmux.conf"
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'erikw/tmux-powerline'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
EOF

# Install Oh-my-zsh and plugins
RUN sh -c "$(curl https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-"${home_dir}/.oh-my-zsh/custom"}/plugins/zsh-syntax-highlighting" && \
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-"${home_dir}/.oh-my-zsh/custom"}/plugins/zsh-autosuggestions" && \
    git clone https://github.com/zsh-users/zsh-completions "${ZSH_CUSTOM:-"${home_dir}/.oh-my-zsh/custom"}/plugins/zsh-completions" && \
    git clone https://github.com/hlissner/zsh-autopair "${ZSH_CUSTOM:-"${home_dir}/.oh-my-zsh/custom"}/plugins/zsh-autopair" && \
    mv "${home_dir}/.zshrc.pre-oh-my-zsh" "${home_dir}/.zshrc"

ARG NEOVIM_CONFIG_BRANCH=master
RUN git clone --branch ${NEOVIM_CONFIG_BRANCH} https://github.com/de-passage/neovim-config.git "${home_dir}/.config/nvim"  && \
    nvim --headless -c 'MasonInstall lua-language-server' -c 'q'
RUN nvim --headless +"Lazy! update" +qa

RUN sed 's!\(checker\s*=\s*{\s*enabled\s*=\s*\)true!\1false!' "${config}/nvim/lua/config/lazy.lua" -i

WORKDIR "${home_dir}/workspace"
