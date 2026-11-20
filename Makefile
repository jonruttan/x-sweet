# x-sweet -- the Sweet lang for x-lang
#
# Install copies this bundle to <share>/langs/sweet, where `x -l` looks: a lang
# is installed when its files are there. No registry, no database.
#
#   make install                        into the x on PATH
#   PREFIX=$HOME/.local make install    into a particular prefix
#
# A pin (lang.pin.xon + Pin bundle) freezes a verified tarball for one project
# and is what a build should depend on. An install is one unversioned copy for
# the whole machine. Pin when the version matters; install to get `x -l sweet`
# working.

X ?= x

# The version is derived from git describe, never committed: a version literal
# is true only at the commit it is tagged on and wrong on every commit after.
# lang.xon declares what this bundle requires; the installed artifact carries
# what it is, in a version stamp -- the same split as x-lang's own
# $(X_RELEASE) -> <lib>/contract/release.
LANG_VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
# PREFIX wins when given, matching x-lang's own `PREFIX=... make install`.
# Otherwise ask the x on PATH where its tree is, via --share-dir.
SHARE := $(if $(PREFIX),$(PREFIX)/share/x,$(shell $(X) --share-dir))
DEST  := $(SHARE)/langs/sweet

# What a consumer needs to run the lang: the declaration, the entry, the
# modules. Not the suite, the tooling, or CI.
PAYLOAD := lang.xon run.x sweet

.PHONY: install
install: ## Install into <share>/langs/sweet
	@test -n "$(SHARE)" || { echo "x-sweet: cannot find an x tree -- set PREFIX or X" >&2; exit 1; }
	@test -d "$(SHARE)" || { echo "x-sweet: no x tree at $(SHARE)" >&2; exit 1; }
	rm -rf "$(DEST)"
	mkdir -p "$(DEST)"
	cp -R $(PAYLOAD) "$(DEST)/"
	printf '%s\n' '$(LANG_VERSION)' > "$(DEST)/version"
	@echo "x-sweet: installed to $(DEST)"
	@echo "x-sweet: writing the boot image"
	"$(X)" --image -l sweet || true
	@echo "x-sweet: try  x -l sweet"

.PHONY: uninstall
uninstall: ## Remove it again
	rm -rf "$(DEST)"
	@echo "x-sweet: removed $(DEST)"

.PHONY: test
test: ## Run the spec suite
	X="$(X)" sh tests/spec-runner.sh

# The card runs from here, so X is an installed x: a checkout's wrapper runs
# only from its own root.  X_LANG_DIR is the directory holding this bundle,
# so `x -l sweet` loads this tree and not an installed copy.  CARD_SH is the
# check: the installed x-lang's, or a newer one named here.
.PHONY: card
card: ## Hold docs/card.md to the card format and run its programs
	X_LANG_DIR="$${X_LANG_DIR:-$(CURDIR)/..}" BUNDLE=. X="$(X)" \
		sh "$${CARD_SH:-$$("$(X)" --share-dir)/tools/lang-kit/card.sh}"

.PHONY: bundle
bundle: ## Roll a release tarball and print its pin
	sh tools/bundle.sh

.PHONY: help
help: ## Show targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  \033[32m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
