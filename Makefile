# Variables
###########

GITROOT=$(shell git rev-parse --show-toplevel)

# Container variables
IMAGE_REPO?=ghcr.io/jaormx
IMAGE_NAME?=externalauthdemo
IMAGE_TAG?=latest
IMAGE_REF=$(IMAGE_REPO)/$(IMAGE_NAME):$(IMAGE_TAG)

# Cilium variables
##################

CILIUM_VERSION=1.12.1
CILIUM_INSTALL_NS?=kube-system

# Metallb variables
###################

METALLB_VERSION=0.12.1

# Kind variables
################
KIND_CLUSTER_NAME?=authtestcluster

# Container targets

.PHONY: image
image:
	@echo "\n>>> Building demo container as '$(IMAGE_REF)'\n"
	docker build -t $(IMAGE_REF) .

.PHONY: container-push
container-push:
	docker push $(IMAGE_REF)

.PHONY: load-demo-container
load-demo-container: image kind-up
	@echo "\n>>> Loading demo container into kind cluster '$(KIND_CLUSTER_NAME)'\n"
	kind load docker-image --name $(KIND_CLUSTER_NAME) $(IMAGE_REF)

# Deployment targets
####################

.PHONY: deploy
deploy:
	kubectl apply -f $(GITROOT)/deploy/deploy.yml

# Cilium targets
#################

.PHONY: load-cilium-container
load-cilium-container: kind-up
	@echo "\n>>> Loading Cilium container into kind cluster '$(KIND_CLUSTER_NAME)'\n"
	docker pull quay.io/cilium/cilium:v$(CILIUM_VERSION)
	kind load docker-image --name $(KIND_CLUSTER_NAME) quay.io/cilium/cilium:v$(CILIUM_VERSION)

.PHONY: setup-cilium-helm-repo
setup-cilium-helm-repo:
	@echo "\n>>> Adding Cilium helm repo\n"
	helm repo add cilium https://helm.cilium.io/

.PHONY: install-cilium
install-cilium: setup-cilium-helm-repo
	@echo "\n>>> Installing Cilium\n"
	helm status --namespace $(CILIUM_INSTALL_NS) cilium || \
		helm install cilium cilium/cilium --version $(CILIUM_VERSION) \
			--namespace $(CILIUM_INSTALL_NS) \
			--set image.pullPolicy=IfNotPresent \
			--set ipam.mode=kubernetes \
			--set ingressController.enabled=true

.PHONY: cilium-status
cilium-status:
	@echo "\n>>> Cilium status\n"
	cilium status --wait

# Setup Metallb
###############

.PHONY: setup-metallb
setup-metallb:
	@echo "\n>>> Installing MetalLB\n"
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$(METALLB_VERSION)/manifests/namespace.yaml
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$(METALLB_VERSION)/manifests/metallb.yaml

	# Wait for rollout status, retry if it's not available yet
	kubectl rollout status daemonset -n metallb-system speaker -w || \
		kubectl rollout status daemonset -n metallb-system speaker -w || \
		kubectl rollout status daemonset -n metallb-system speaker -w

# Kind targets
##############

.PHONY: kind-up
kind-up:
	@echo "\n>>> Ensuring kind cluster '$(KIND_CLUSTER_NAME)' is up\n"
	kind get clusters | grep -q $(KIND_CLUSTER_NAME) || \
		kind create cluster --name "$(KIND_CLUSTER_NAME)" --config="$(GITROOT)/tests/envsetup/kindcluster.yaml"

.PHONY: kind-down
kind-down:
	@echo "\n>>> Deleting kind cluster '$(KIND_CLUSTER_NAME)'\n"
	kind delete cluster --name "$(KIND_CLUSTER_NAME)"

# Test environment setup
########################

.PHONY: test-env-setup
test-env-setup: kind-up load-cilium-container install-cilium cilium-status setup-metallb load-demo-container deploy load-test-app-container setup-test-app

.PHONY: load-test-app-container
load-test-app-container: kind-up
	@echo "\n>>> Loading test app container into kind cluster '$(KIND_CLUSTER_NAME)'\n"
	docker pull jmalloc/echo-server:latest
	kind load docker-image --name $(KIND_CLUSTER_NAME) jmalloc/echo-server:latest

.PHONY: setup-test-app
setup-test-app:
	@echo "\n>>> Setting up test app\n"
	kubectl apply -f $(GITROOT)/tests/app/app.yml
