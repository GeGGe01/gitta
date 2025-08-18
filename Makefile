# Simple Makefile for Python + nfpm packaging
PROJECT := gitta
VERSION ?= 0.1.0
ARCH ?= amd64
DIST := dist

.PHONY: help build wheel package clean publish test-package fmt

help:
	@echo "Targets: build, wheel, package, publish, test-package, clean"

build: wheel ## Build python sdist/wheel

wheel:
	python3 -m pip install --upgrade build >/dev/null 2>&1 || true
	python3 -m build

package: ## Build .deb via nfpm
	mkdir -p $(DIST)
	nfpm pkg --packager deb -f nfpm.yaml --target $(DIST)/$(PROJECT)_$(VERSION)_$(ARCH).deb

package-keyring: ## Build archive keyring .deb (requires exported key at build/gpg/pubkey.asc)
	mkdir -p $(DIST)
	@test -f build/gpg/pubkey.asc || (echo "Missing build/gpg/pubkey.asc. Export with: gpg --armor --export <FPR> > build/gpg/pubkey.asc" && false)
	nfpm pkg --packager deb -f nfpm.keyring.yaml --target $(DIST)/$(PROJECT)-archive-keyring_$(VERSION)_all.deb

publish: ## Publish to gh-pages apt repo (local test)
	@[ -d repo ] || mkdir -p repo
	cp -v $(DIST)/$(PROJECT)_$(VERSION)_$(ARCH).deb repo/
	( cd repo && ../build/publish-apt.sh )

test-package: ## Smoke test .deb in Docker Ubuntu
	bash scripts/smoke-test.sh $(DIST)/$(PROJECT)_$(VERSION)_$(ARCH).deb

clean:
	rm -rf build/ dist/ *.egg-info .pytest_cache .mypy_cache .ruff_cache
