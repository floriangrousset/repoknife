# repoknife — local dev tasks. Run `make` (or `make help`).
SHELL     := /bin/bash
VERSION   := $(shell grep -E '^VERSION="[0-9]+\.[0-9]+\.[0-9]+"' repoknife | head -1 | sed -E 's/^VERSION="([^"]+)".*/\1/')
CODE_ROOT ?= $(HOME)/Code
SYMLINK   := $(CODE_ROOT)/repoknife
DISTBIN   := dist/repoknife

.DEFAULT_GOAL := help
.PHONY: help check selftest shellcheck guard build install-dev install-brew-local changelog version release-dry-run clean

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

changelog: ## preview the changelog for the unreleased commits (needs git-cliff)
	@command -v git-cliff >/dev/null || { echo "git-cliff not installed — brew install git-cliff"; exit 1; }
	@git-cliff --unreleased --bump --strip header

version: ## show the last-released VERSION and the next version git-cliff would compute
	@echo "VERSION (last release): $(VERSION)"
	@command -v git-cliff >/dev/null \
	  && echo "next (computed):        $$(git-cliff --bumped-version 2>/dev/null)" \
	  || echo "next (computed):        (install git-cliff to compute)"

release-dry-run: check ## what release.yml will do on the next develop->main merge (no push/tag)
	@command -v git-cliff >/dev/null || { echo "git-cliff not installed — brew install git-cliff"; exit 1; }
	@next="$$(git-cliff --bumped-version 2>/dev/null)"; \
	  last="$$(git describe --tags --abbrev=0 2>/dev/null || echo none)"; \
	  echo "last tag: $$last   next: $$next"; \
	  if [ "$$next" = "$$last" ]; then echo "no releasable commits — release would no-op"; \
	  else echo "release would: set VERSION=$${next#v}, regenerate CHANGELOG.md, tag $$next, publish, bump tap"; fi

clean: ## remove dist/
	rm -rf dist
