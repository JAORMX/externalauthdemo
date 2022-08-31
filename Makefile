# Variables
###########

GITROOT=$(shell git rev-parse --show-toplevel)

# Container variables
IMAGE_REPO?=ghcr.io/jaormx
IMAGE_NAME?=externalauthdemo
IMAGE_TAG?=latest
IMAGE_REF=$(IMAGE_REPO)/$(IMAGE_NAME):$(IMAGE_TAG)

# Kind variables
################
KIND_CLUSTER_NAME?=authtestcluster

# Container targets

.PHONY: image
image:
	docker build -t $(IMAGE_REF) .

.PHONY: container-push
container-push:
	docker push $(IMAGE_REF)

# Kind targets
##############

.PHONY: kind-up
kind-up:
	kind create cluster --name "$(KIND_CLUSTER_NAME)" --config="$(GITROOT)/tests/envsetup/kindcluster.yaml"

.PHONY: kind-down
kind-down:
	kind delete cluster --name "$(KIND_CLUSTER_NAME)"
