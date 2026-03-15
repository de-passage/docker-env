ARG BASE_TAG=nightly
FROM git.sylvainleclercq.com/depassage/coder-base:${BASE_TAG}

USER root
RUN pacman -Syu --noconfirm cmake gdb clang lldb gcc
USER dev
RUN nvim --headless +"MasonInstall clangd" +q
RUN mkdir /home/dev/.config/nvim/lua/config/local && \
cat > /home/dev/.config/nvim/lua/config/local/lspconfig.lua <<EOF
return {
  servers = { "clangd" }
}
EOF

WORKDIR  /home/dev
