FROM ubuntu:24.04

RUN apt-get update && apt-get install -y curl git sudo xz-utils ca-certificates && rm -rf /var/lib/apt/lists/*

RUN useradd -m dev && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER dev

WORKDIR /home/dev

RUN curl -L http://nixos.org/nix/install | sh

ENV PATH="/home/dev/.nix-profile/bin:/home/dev/.nix-profile/sbin:$PATH"

RUN mkdir -p ~/.config/nix && echo "experimental-features = nix-command flakes"