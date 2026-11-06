# TheRecruitingCompass iOS - Build & Test
# Usage: make build | test | test-unit | test-unit-fast

PROJECT_DIR := TheRecruitingCompass
SCHEME := TheRecruitingCompass
# Per-machine overrides (gitignored), e.g. pin a simulator by id when the default
# runtime is unusable locally: DESTINATION := platform=iOS Simulator,id=<UDID>
-include Makefile.local
# Empty: tests run on the shared "TRC Agent iPhone" and builds target any simulator.
DESTINATION ?=
IPAD_DESTINATION := platform=iOS Simulator,name=iPad Air 11-inch (M4)
# Every test target goes through scripts/run-ios-tests.sh: one simulator run at a time across the Mac
# (other agents wait their turn), serial testing, and the simulator shut down afterwards, pass or fail.
# KEEP_SIM=1 leaves it running for debugging.
RUN_TESTS := ./scripts/run-ios-tests.sh $(if $(KEEP_SIM),--keep-sim)
TEST_DESTINATION := $(if $(DESTINATION),--destination '$(DESTINATION)')
WEB_DIR := ../recruiting-compass-web

.PHONY: build test test-ui test-unit test-unit-fast build-ipad test-ipad test-all-devices \
	clean setup-hooks lint e2e-precheck e2e-seed e2e-local

build:
	cd $(PROJECT_DIR) && xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(or $(DESTINATION),generic/platform=iOS Simulator)' \
		-quiet

# Full test suite (unit + UI tests)
test:
	$(MAKE) test-unit
	$(MAKE) test-ui

# UI tests only (retries known simulator launch errors)
test-ui:
	$(RUN_TESTS) --ui $(TEST_DESTINATION)

# Unit tests only (skip UI tests) - significantly faster
test-unit:
	$(RUN_TESTS) --unit $(TEST_DESTINATION)

# Kept as an alias: parallel clone simulators overran this Mac, so all local runs are serial now.
test-unit-fast: test-unit

# iPad build target
build-ipad:
	cd $(PROJECT_DIR) && xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(IPAD_DESTINATION)' \
		$(XCARGS)

# iPad unit tests (skip UI tests for iPad device testing)
test-ipad:
	$(RUN_TESTS) --unit --destination '$(IPAD_DESTINATION)' -- -test-timeouts-enabled YES $(XCARGS)

# Test all devices (iPhone + iPad)
test-all-devices: test-unit test-ipad

# Clean build artifacts
clean:
	cd $(PROJECT_DIR) && xcodebuild clean \
		-scheme $(SCHEME) \
		-quiet

# Install pre-commit hook (one-time setup per clone)
setup-hooks:
	git config core.hooksPath .githooks
	@echo "Pre-commit hook installed."

# Run SwiftLint across the whole codebase
lint:
	swiftlint lint --config .swiftlint.yml --quiet

# ---------------------------------------------------------------------------
# E2E (UI tests) — always against the LOCAL Supabase stack, never production.
# Requires Docker + `supabase start` in the web repo. See docs/E2E_TESTING.md.
# ---------------------------------------------------------------------------

# Fail fast with a helpful message if the local Supabase stack is not running.
e2e-precheck:
	@cd $(WEB_DIR) && supabase status >/dev/null 2>&1 || { \
		echo "Local Supabase stack is not running."; \
		echo "Start it:  cd $(WEB_DIR) && supabase start   (Docker required)"; \
		exit 1; }
	@echo "Local Supabase stack is up."

# Seed the local stack with the canonical fixture (parent + linked player).
e2e-seed: e2e-precheck
	cd scripts && npm run seed:e2e

# Full local E2E: ensure stack is up -> seed -> run UI tests against local Supabase.
e2e-local: e2e-seed
	$(MAKE) test-ui

# Override DESTINATION if needed (name= or id=):
#   make test-unit DESTINATION='platform=iOS Simulator,name=iPhone 16e'
# or set it once per machine in Makefile.local (see top of file).
