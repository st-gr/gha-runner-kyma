# gha-runner-kyma Makefile
#
# Targets assume `kubectl` and `node` on PATH, with kubectl authenticated
# against the target Kyma cluster. Credentials never reach Make
# variables — the Secret is created interactively via
# `make runner-create-secret` (see scripts/create-runner-secret.js).

.SHELLFLAGS := -eu -o pipefail -c

RUNNER_NS ?= gh-runner
OWNER ?=
REPO ?=

.PHONY: help
help:
	@echo "  runner-deploy        apply namespace + SA + ConfigMaps + NetworkPolicy"
	@echo "  runner-create-secret interactively create gh-runner-creds Secret"
	@echo "  runner-add-repo      OWNER=<owner> REPO=<repo>"
	@echo "  runner-remove-repo   OWNER=<owner> REPO=<repo>"
	@echo "  runner-status        list runner pods"
	@echo "  runner-logs          OWNER=<owner> REPO=<repo>"

.PHONY: runner-deploy
runner-deploy:
	kubectl apply -f namespace.yaml
	kubectl apply -f serviceaccount.yaml
	kubectl apply -f configmap.yaml
	kubectl apply -f configmap-entrypoint.yaml
	kubectl apply -f networkpolicy.yaml
	@echo ""
	@echo "Namespace, SA, ConfigMaps, and NetworkPolicy applied."
	@echo "Next: create the credentials Secret with"
	@echo "    make runner-create-secret"
	@echo "Then add a runner per repo with"
	@echo "    make runner-add-repo OWNER=<owner> REPO=<repo>"

.PHONY: runner-create-secret
runner-create-secret:
	@node scripts/create-runner-secret.js $(RUNNER_NS)

.PHONY: runner-add-repo
runner-add-repo:
ifeq ($(strip $(OWNER)),)
	$(error OWNER is required, e.g. OWNER=st-gr REPO=OpenShell)
endif
ifeq ($(strip $(REPO)),)
	$(error REPO is required, e.g. OWNER=st-gr REPO=OpenShell)
endif
	node scripts/add-runner-repo.js --owner $(OWNER) --repo $(REPO) --namespace $(RUNNER_NS) --apply

.PHONY: runner-remove-repo
runner-remove-repo:
ifeq ($(strip $(OWNER)),)
	$(error OWNER is required)
endif
ifeq ($(strip $(REPO)),)
	$(error REPO is required)
endif
	node scripts/remove-runner-repo.js --owner $(OWNER) --repo $(REPO) --namespace $(RUNNER_NS)

.PHONY: runner-status
runner-status:
	@kubectl -n $(RUNNER_NS) get pods -L runner-repo

.PHONY: runner-logs
runner-logs:
ifeq ($(strip $(OWNER)),)
	$(error OWNER is required)
endif
ifeq ($(strip $(REPO)),)
	$(error REPO is required)
endif
	kubectl -n $(RUNNER_NS) logs -f deployment/runner-$(shell echo $(OWNER) | tr '[:upper:]' '[:lower:]')-$(shell echo $(REPO) | tr '[:upper:]' '[:lower:]')
