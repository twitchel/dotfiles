FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ARG DOTFILES_BRANCH

RUN echo "Running on branch: ${DOTFILES_BRANCH}"

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl \
    sudo

RUN useradd -m -s /bin/zsh -d /home/docker-ci docker-ci &&  \
    echo "docker-ci ALL=NOPASSWD: ALL" >> /etc/sudoers

USER docker-ci

RUN mkdir -p /home/docker-ci/dev/src/github.com/twitchel

COPY --chown=docker-ci:docker-ci ./ /home/docker-ci/dev/src/github.com/twitchel/dotfiles

WORKDIR /home/docker-ci/dev/src/github.com/twitchel/dotfiles

RUN DOTFILES_BRANCH=${DOTFILES_BRANCH} sh install.sh

RUN sh ./tests/run-test.sh

