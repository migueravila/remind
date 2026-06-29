.PHONY: build test install uninstall clean format lint release dev bump help

BINARY_NAME = remind
BUILD_PATH = .build/release/$(BINARY_NAME)
INSTALL_PATH = /usr/local/bin/$(BINARY_NAME)
VERSION ?= $(shell cat version 2>/dev/null || echo "0.0.0")

build:
	swift build -c release

test:
	swift test

format:
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat --config .format Sources/; \
		echo "Code formatted"; \
	else \
		echo "swiftformat not found. Install with: brew install swiftformat"; \
	fi

lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
		echo "Linting complete"; \
	else \
		echo "swiftlint not found. Install with: brew install swiftlint"; \
	fi

clean:
	swift package clean
	rm -rf .build release

install: build
	sudo cp $(BUILD_PATH) $(INSTALL_PATH)
	@echo "$(BINARY_NAME) installed to $(INSTALL_PATH)"

uninstall:
	sudo rm -f $(INSTALL_PATH)
	@echo "$(BINARY_NAME) uninstalled"

release: clean build
	mkdir -p release
	cp $(BUILD_PATH) release/
	cd release && tar -czf $(BINARY_NAME)-$(VERSION)-macos.tar.gz $(BINARY_NAME)
	cd release && shasum -a 256 $(BINARY_NAME)-$(VERSION)-macos.tar.gz > $(BINARY_NAME)-$(VERSION)-macos.tar.gz.sha256
	@echo "Release created: release/$(BINARY_NAME)-$(VERSION)-macos.tar.gz"

dev: format lint test build
	@echo "Development workflow complete"

bump:
	@if [ -z "$(TO)" ]; then \
		echo "Usage: make bump TO=1.2.0"; \
		exit 1; \
	fi
	@echo "$(TO)" > version
	@sed -i.bak 's/public static let version = ".*"/public static let version = "$(TO)"/' Sources/commands/help.swift
	@rm -f Sources/commands/help.swift.bak
	@echo "Bumped to $(TO)"

help:
	@echo "Available commands:"
	@echo "  build     - Build release binary"
	@echo "  test      - Run tests"
	@echo "  format    - Format Swift code"
	@echo "  lint      - Lint Swift code"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install binary locally"
	@echo "  uninstall - Remove binary"
	@echo "  release   - Create release package"
	@echo "  dev       - Run development workflow"
	@echo "  bump      - Bump version (updates version file + Swift constant)"
	@echo ""
	@echo "Examples:"
	@echo "  make dev                # Full workflow"
	@echo "  make bump TO=1.2.0      # Bump version to 1.2.0"
	@echo "  make release            # Use version from ./version"

