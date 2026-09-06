# Makefile — local reproduction of the CI build + the BATS test suites.
#
# Everything runs in containers so it matches GitHub Actions. Requires docker;
# on a podman host pass CONTAINER_RUNTIME=podman.
#
#   make test          # fast render-tier BATS suite (fedora + ubuntu)
#   make ci            # reproduce the GitHub chezmoi init/data/apply build
#   make test-apply    # slower apply-tier BATS suite (real chezmoi apply)
#
# The *-native targets are the actual commands; they run in the CURRENT
# environment and are what the CI containers (and this Makefile's own
# containers) invoke. The wrapper targets just docker-run them per distro.

CONTAINER_RUNTIME ?= docker
IMAGE_FEDORA      ?= fedora:44
IMAGE_UBUNTU      ?= ubuntu:26.04
REPO              := $(CURDIR)

TEST_IMG_FEDORA := chezmoi-test:fedora
TEST_IMG_UBUNTU := chezmoi-test:ubuntu

BATS          := test/vendor/bats-core/bin/bats
RENDER_SUITES := test/render.bats test/scripts.bats test/zsh.bats
APPLY_SUITES  := test/apply.bats

# Pinned BATS versions (override to bump).
BATS_CORE_REF    ?= v1.11.0
BATS_SUPPORT_REF ?= v0.3.0
BATS_ASSERT_REF  ?= v2.1.0

# docker run against a RAW base image (repo mounted read-only), running the CI
# bootstrap script. $(1) = image.
raw_run = $(CONTAINER_RUNTIME) run --rm -v "$(REPO)":/repo:ro -w /repo -e CI=true $(1) sh /repo/test/ci-bootstrap.sh

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

## ---- BATS vendoring ----

.PHONY: vendor
vendor: test/vendor/bats-core test/vendor/bats-support test/vendor/bats-assert ## Download pinned BATS into test/vendor/

test/vendor/bats-core:
	git clone --depth 1 --branch $(BATS_CORE_REF) https://github.com/bats-core/bats-core.git $@

test/vendor/bats-support:
	git clone --depth 1 --branch $(BATS_SUPPORT_REF) https://github.com/bats-core/bats-support.git $@

test/vendor/bats-assert:
	git clone --depth 1 --branch $(BATS_ASSERT_REF) https://github.com/bats-core/bats-assert.git $@

## ---- Test images ----

.PHONY: build build-fedora build-ubuntu
build: build-fedora build-ubuntu ## Build both test images

build-fedora:
	$(CONTAINER_RUNTIME) build -f test/Dockerfile --build-arg BASE_IMAGE=$(IMAGE_FEDORA) -t $(TEST_IMG_FEDORA) .

build-ubuntu:
	$(CONTAINER_RUNTIME) build -f test/Dockerfile --build-arg BASE_IMAGE=$(IMAGE_UBUNTU) -t $(TEST_IMG_UBUNTU) .

## ---- Render-tier tests (fast, no Homebrew) ----

.PHONY: test test-fedora test-ubuntu test-native
test: test-fedora test-ubuntu ## Run the render-tier suite in both distros

test-fedora: vendor build-fedora
	$(CONTAINER_RUNTIME) run --rm -v "$(REPO)":/repo:ro -w /repo $(TEST_IMG_FEDORA) make test-native

test-ubuntu: vendor build-ubuntu
	$(CONTAINER_RUNTIME) run --rm -v "$(REPO)":/repo:ro -w /repo $(TEST_IMG_UBUNTU) make test-native

test-native: ## Run the render-tier BATS suite in the current environment
	$(BATS) $(RENDER_SUITES)

## ---- Apply-tier tests (slower; real chezmoi apply as non-root) ----

.PHONY: test-apply test-apply-fedora test-apply-ubuntu test-apply-native
test-apply: test-apply-fedora test-apply-ubuntu ## Run the apply-tier suite in both distros

test-apply-fedora: vendor build-fedora
	$(CONTAINER_RUNTIME) run --rm -v "$(REPO)":/repo:ro -w /repo --user tester $(TEST_IMG_FEDORA) make test-apply-native

test-apply-ubuntu: vendor build-ubuntu
	$(CONTAINER_RUNTIME) run --rm -v "$(REPO)":/repo:ro -w /repo --user tester $(TEST_IMG_UBUNTU) make test-apply-native

test-apply-native: ## Run the apply-tier BATS suite in the current environment
	$(BATS) $(APPLY_SUITES)

## ---- CI reproduction (chezmoi init/data/apply, mirrors the workflow) ----

.PHONY: ci ci-fedora ci-ubuntu ci-native
ci: ci-fedora ci-ubuntu ## Reproduce the GitHub CI build in both distros

ci-fedora:
	$(call raw_run,$(IMAGE_FEDORA))

ci-ubuntu:
	$(call raw_run,$(IMAGE_UBUNTU))

ci-native: ## The CI build steps (chezmoi init/data/apply) in the current environment
	chezmoi init -S . --no-tty
	chezmoi data -S .
	chezmoi apply -S . --no-tty

## ---- Debug / cleanup ----

.PHONY: shell-fedora shell-ubuntu clean
shell-fedora: build-fedora ## Interactive shell in the Fedora test image
	$(CONTAINER_RUNTIME) run --rm -it -v "$(REPO)":/repo:ro -w /repo $(TEST_IMG_FEDORA) bash

shell-ubuntu: build-ubuntu ## Interactive shell in the Ubuntu test image
	$(CONTAINER_RUNTIME) run --rm -it -v "$(REPO)":/repo:ro -w /repo $(TEST_IMG_UBUNTU) bash

clean: ## Remove vendored BATS and built test images
	rm -rf test/vendor
	-$(CONTAINER_RUNTIME) rmi $(TEST_IMG_FEDORA) $(TEST_IMG_UBUNTU) 2>/dev/null || true
