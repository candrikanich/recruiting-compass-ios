# TheRecruitingCompass iOS - Build & Test
# Usage: make build | test | test-unit | test-unit-fast

PROJECT_DIR := TheRecruitingCompass
SCHEME := TheRecruitingCompass
DESTINATION ?= platform=iOS Simulator,name=iPhone 17

.PHONY: build test test-ui test-unit test-unit-fast clean setup-hooks lint

build:
	cd $(PROJECT_DIR) && xcodebuild build \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-quiet

# Full test suite (unit + UI tests)
# Runs fast unit tests first, then resilient UI tests with retry.
test:
	$(MAKE) test-unit-fast DESTINATION='$(DESTINATION)'
	./scripts/run_ui_tests_resilient.sh "$(PROJECT_DIR)" "$(SCHEME)" "$(DESTINATION)"

# UI tests only with simulator preflight and retry
test-ui:
	./scripts/run_ui_tests_resilient.sh "$(PROJECT_DIR)" "$(SCHEME)" "$(DESTINATION)"

# Unit tests only (skip UI tests) - significantly faster
# Use for rapid feedback during development
test-unit:
	cd $(PROJECT_DIR) && xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-skip-testing:TheRecruitingCompassUITests \
		-quiet

# Unit tests with parallel execution - fastest option
# Uses multiple simulator clones when available
test-unit-fast:
	cd $(PROJECT_DIR) && xcodebuild test \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-skip-testing:TheRecruitingCompassUITests \
		-parallel-testing-enabled YES \
		-maximum-concurrent-test-simulator-destinations 2 \
		-quiet

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

# Override DESTINATION if needed (e.g. simulator resource limits):
#   make test-unit DESTINATION='platform=iOS Simulator,name=iPhone 16e'
