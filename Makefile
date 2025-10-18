BUILDDIR := build/
NAME := ipvfoo
MANIFEST := src/manifest.json
MANIFEST_F := manifest/firefox-manifest.json
MANIFEST_C := manifest/chrome-manifest.json
VERSION_F := $(shell cat ${MANIFEST_F} | \
	sed -n 's/^ *"version": *"\([0-9.]\+\)".*/\1/p' | \
	head -n1)
VERSION_C := $(shell cat ${MANIFEST_C} | \
	sed -n 's/^ *"version": *"\([0-9.]\+\)".*/\1/p' | \
	head -n1)

# Verbosity levels: 0=quiet, 1=normal, 2=verbose, 5=debug
LOG_VERBOSITY ?= 0
ifeq ($(CONFIGURATION),Debug)
DEBUG := 1
RELEASE := 0
else
DEBUG := 0
RELEASE := 1
endif

BUILD_ENV := RELEASE=$(RELEASE) DEBUG=$(DEBUG) LOG_VERBOSITY=$(LOG_VERBOSITY)

install:
	pnpm install

all: prepare firefox chrome safari

# PNPM build commands
build-all:
	$(BUILD_ENV) pnpm run build

build-firefox-pnpm:
	$(BUILD_ENV) pnpm run build:firefox

build-chrome-pnpm:
	$(BUILD_ENV) pnpm run build:chrome

build-safari-pnpm:
	$(BUILD_ENV) pnpm run build:safari

# PNPM watch commands
watch:
	$(BUILD_ENV) pnpm run watch

watch-debug:
	$(BUILD_ENV) pnpm run watch:debug

watch-firefox:
	$(BUILD_ENV) pnpm run watch:firefox

watch-chrome:
	$(BUILD_ENV) pnpm run watch:chrome

watch-safari:
	$(BUILD_ENV) pnpm run watch:safari

XCODE_PROJECT := safari/ipvfoo-safari.xcodeproj
XCODE_SCHEME_IOS := ipvfoo-safari\ \(iOS\)
XCODE_SCHEME_MACOS := ipvfoo-safari\ \(macOS\)
XCODE_ENV := RELEASE=$(RELEASE) DEBUG=$(DEBUG) LOG_VERBOSITY=$(LOG_VERBOSITY) SKIP_SCRIPT_PHASE=1
DERIVED_DATA := safari/build

prepare:
	@diff ${MANIFEST} ${MANIFEST_F} >/dev/null || \
		diff ${MANIFEST} ${MANIFEST_C} >/dev/null || \
		(echo "${MANIFEST} is not a copy of ${MANIFEST_F} or ${MANIFEST_C}; aborting."; exit 1)
	mkdir -p build

firefox: prepare
	rm -f ${BUILDDIR}${NAME}-${VERSION_F}.xpi
	cp -f ${MANIFEST_F} ${MANIFEST}
	zip -9j ${BUILDDIR}${NAME}-${VERSION_F}.xpi -j src/*

chrome: prepare
	rm -f ${BUILDDIR}${NAME}-${VERSION_C}.zip
	cp -f ${MANIFEST_C} ${MANIFEST}
	zip -9j ${BUILDDIR}${NAME}-${VERSION_C}.zip -j src/*

safari: safari-build-resources
	@echo "Building Safari extension..."

safari-build-resources:
	@echo "Building extension resources for Xcode..."
	${BUILD_ENV} pnpm run build:safari

safari-add-xcode-targets: safari-build-resources
	@echo "Adding resources to Xcode project targets..."
	@bash scripts/add-xcode-targets.sh

safari-ios: safari-add-xcode-targets
	@echo "Building Safari iOS app (Release)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Release \
		-derivedDataPath ${DERIVED_DATA} \
		${XCODE_ENV} \
		clean build

safari-ios-debug: safari-add-xcode-targets
	@echo "Building Safari iOS app (Debug)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Debug \
		-derivedDataPath ${DERIVED_DATA} \
		${XCODE_ENV} \
		clean build

safari-macos: safari-add-xcode-targets
	@echo "Building Safari macOS app (Release)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_MACOS} \
		-configuration Release \
		-derivedDataPath ${DERIVED_DATA} \
		${XCODE_ENV} \
		clean build

safari-macos-debug: safari-add-xcode-targets
	@echo "Building Safari macOS app (Debug)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_MACOS} \
		-configuration Debug \
		-derivedDataPath ${DERIVED_DATA} \
		${XCODE_ENV} \
		clean build

safari-run-ios: safari-ios-debug
	@echo "Running Safari iOS app in simulator..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Debug \
		-derivedDataPath ${DERIVED_DATA} \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		${XCODE_ENV} \
		run

safari-run-macos: safari-macos-debug
	@echo "Running Safari macOS app..."
	open ${DERIVED_DATA}/Build/Products/Debug/ipvfoo-safari.app

safari-archive-ios: safari-add-xcode-targets
	@echo "Archiving Safari iOS app..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Release \
		-archivePath ${DERIVED_DATA}/ipvfoo-ios.xcarchive \
		${XCODE_ENV} \
		archive

safari-archive-macos: safari-add-xcode-targets
	@echo "Archiving Safari macOS app..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_MACOS} \
		-configuration Release \
		-archivePath ${DERIVED_DATA}/ipvfoo-macos.xcarchive \
		${XCODE_ENV} \
		archive

safari-clean:
	rm -rf ${DERIVED_DATA}
	rm -rf safari/Shared\ \(Extension\)/Resources/*.js
	rm -rf safari/Shared\ \(Extension\)/Resources/*.map
	rm -rf safari/Shared\ \(Extension\)/Resources/*.html
	rm -rf safari/Shared\ \(Extension\)/Resources/manifest.json

clean:
	rm -rf ${BUILDDIR}
	$(MAKE) safari-clean

.PHONY: install all prepare firefox chrome safari build-all build-firefox-pnpm build-chrome-pnpm build-safari-pnpm watch watch-debug watch-firefox watch-chrome watch-safari safari-build-resources safari-add-xcode-targets safari-ios safari-ios-debug safari-macos safari-macos-debug safari-run-ios safari-run-macos safari-archive-ios safari-archive-macos safari-clean clean
