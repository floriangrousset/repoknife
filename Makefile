# repoknife — local dev tasks. Run `make` (or `make help`).
SHELL     := /bin/bash
VERSION   := $(shell grep -E '^VERSION="[0-9]+\.[0-9]+\.[0-9]+"' repoknife | head -1 | sed -E 's/^VERSION="([^"]+)".*/\1/')
CODE_ROOT ?= $(HOME)/Code
SYMLINK   := $(CODE_ROOT)/repoknife
DISTBIN   := dist/repoknife

.DEFAULT_GOAL := help
.PHONY: help check selftest shellcheck guard build install-dev install-brew-local release-dry-run clean

help: ## list targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  %-20s %s\n",$$1,$$2}'

check: selftest shellcheck guard ## full house verification loop

selftest: ## run the self-diagnostic (needs bash >= 4.4)
	./repoknife _selftest

shellcheck: ## lint the script (must be clean)
	shellcheck repoknife

guard: ## assert the bash-3.2 friendly guard fires on system bash
	@set +e; out="$$(/bin/bash ./repoknife --version 2>&1)"; rc=$$?; set -e; \
	  test "$$rc" -eq 1 || { echo "FAIL: expected rc 1, got $$rc"; exit 1; }; \
	  case "$$out" in *"requires bash >= 4.4"*) echo "guard OK ($$out)";; \
	    *) echo "FAIL: guard message missing"; exit 1;; esac

build: ## produce dist/repoknife + dist/repoknife.sha256
	@mkdir -p dist
	cp repoknife $(DISTBIN)
	chmod +x $(DISTBIN)
	cd dist && shasum -a 256 repoknife > repoknife.sha256
	@echo "built v$(VERSION):"; cat dist/repoknife.sha256

install-dev: ## classic ~/Code symlink to the working-tree script
	ln -sfn "$(CURDIR)/repoknife" "$(SYMLINK)"
	@echo "symlinked $(SYMLINK) -> $(CURDIR)/repoknife"

install-brew-local: build ## (re)install from the tap formula, build from source
	brew install --build-from-source floriangrousset/tap/repoknife \
	  || brew reinstall floriangrousset/tap/repoknife

release-dry-run: check build ## everything release.yml does except push/tag/release
	@echo "would create tag v$(VERSION) + release with:"; ls -l dist
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null \
	  && echo "WARNING: tag v$(VERSION) already exists (release would no-op)" \
	  || echo "tag v$(VERSION) is free"

clean: ## remove dist/
	rm -rf dist
