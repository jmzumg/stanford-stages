include .build-args
export

IMAGE_NAME := docker.gitlab.gwdg.de/medinf/kvf/kvf-projekte/xnat/stanford-stages
TAG ?= latest
DOCKERFILE := Dockerfile.xnat-notebook
# The notebook base image is on quay.io (not Docker Hub), so it is not routed
# through the Nexus mirror. UBUNTU_MIRROR only redirects the base's apt sources
# onto the GWDG HTTPS mirror (plain HTTP is blocked on the GWDG network).
UBUNTU_MIRROR ?= https://ftp.gwdg.de/pub/linux/debian/ubuntu

BUILD_ARGS := --build-arg JH_VERSION=$(JH_VERSION) --build-arg UBUNTU_MIRROR=$(UBUNTU_MIRROR)

.PHONY: assets build
# Populate ml/ac/ with the ~770 MiB LSTM models; skipped if already present.
assets:
	./get_assets.sh models

build: assets
	docker build --provenance=false -f $(DOCKERFILE) $(BUILD_ARGS) --tag $(IMAGE_NAME):$(TAG) .
