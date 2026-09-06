# Test image for the chezmoi BATS suite.
# Parameterised by distro so one Dockerfile serves fedora:44 and ubuntu:26.04.
#
#   docker build -f test/Dockerfile --build-arg BASE_IMAGE=fedora:44 -t chezmoi-test:fedora .
#
# Installs chezmoi + the tooling the tests need, and adds a non-root `tester`
# user with passwordless sudo so the apply tier can install Homebrew (its
# installer refuses to run as root).
ARG BASE_IMAGE=fedora:44
FROM ${BASE_IMAGE}

# Base tooling: git/curl for chezmoi + its externals, sudo for the apply tier,
# coreutils for sha256sum, procps/which as common shell deps.
RUN if command -v dnf >/dev/null 2>&1; then \
        dnf install -y git curl bash sudo make ca-certificates coreutils which procps-ng >/dev/null && dnf clean all; \
    elif command -v apt-get >/dev/null 2>&1; then \
        apt-get update >/dev/null && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y git curl bash sudo make ca-certificates coreutils procps >/dev/null && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "unsupported base image: no dnf or apt-get" && exit 1; \
    fi

# chezmoi (matches the version pinning strategy of the CI workflow: latest).
RUN sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin

# Non-root user with passwordless sudo for the apply tier.
RUN useradd -m -s /bin/bash tester && \
    printf 'tester ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/tester && \
    chmod 0440 /etc/sudoers.d/tester

WORKDIR /repo
