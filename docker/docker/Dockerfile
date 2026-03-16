FROM git.sylvainleclercq.com/depassage/coder-base:nightly

USER root
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      docker \
      docker-buildx \
      openssh \
      git \
      github-cli \
      jq

USER dev
WORKDIR /dev/coder
