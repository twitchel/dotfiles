FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV DOTFILES_LOCAL_COPY=true
ARG DOTFILES_BRANCH

RUN echo "Running on branch: ${DOTFILES_BRANCH}"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    sudo \
    bats

RUN useradd -m -s /bin/zsh -d /home/docker-ci docker-ci &&  \
    echo "docker-ci ALL=NOPASSWD: ALL" >> /etc/sudoers

USER docker-ci

RUN mkdir -p /home/docker-ci/.local/share/chezmoi

COPY --chown=docker-ci:docker-ci ./ /home/docker-ci/.local/share/chezmoi

WORKDIR /home/docker-ci/.local/share/chezmoi

RUN sh install.sh