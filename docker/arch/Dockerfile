FROM archlinux/archlinux

RUN pacman -Syu --needed --noconfirm base-devel bash git neovim vim
# RUN mkdir /tmp/downloads -p && cd /tmp/downloads && \
#     git clone https://aur.archlinux.org/yay-bin.git &&  \
#     cd yay-bin && makepkg -si
# RUN yay -Y --gendb 
# RUN yay -S neovim

RUN useradd -m dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev

RUN git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim && \
    git clone https://github.com/de-passage/neovim-config.git ~/.config/nvim && \
    nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
