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

all: prepare firefox chrome safari

XCODE_PROJECT := safari/ipvfoo-safari.xcodeproj
XCODE_SCHEME_IOS := ipvfoo-safari\ \(iOS\)
XCODE_SCHEME_MACOS := ipvfoo-safari\ \(macOS\)
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
	pnpm run build:xcode

safari-ios: safari-build-resources
	@echo "Building Safari iOS app (Release)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Release \
		-derivedDataPath ${DERIVED_DATA} \
		clean build

safari-ios-debug: safari-build-resources
	@echo "Building Safari iOS app (Debug)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Debug \
		-derivedDataPath ${DERIVED_DATA} \
		clean build

safari-macos: safari-build-resources
	@echo "Building Safari macOS app (Release)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_MACOS} \
		-configuration Release \
		-derivedDataPath ${DERIVED_DATA} \
		clean build

safari-macos-debug: safari-build-resources
	@echo "Building Safari macOS app (Debug)..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_MACOS} \
		-configuration Debug \
		-derivedDataPath ${DERIVED_DATA} \
		clean build

safari-run-ios: safari-ios-debug
	@echo "Running Safari iOS app in simulator..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Debug \
		-derivedDataPath ${DERIVED_DATA} \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		run

safari-run-macos: safari-macos-debug
	@echo "Running Safari macOS app..."
	open ${DERIVED_DATA}/Build/Products/Debug/ipvfoo-safari.app

safari-archive-ios: safari-build-resources
	@echo "Archiving Safari iOS app..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_IOS} \
		-configuration Release \
		-archivePath ${DERIVED_DATA}/ipvfoo-ios.xcarchive \
		archive

safari-archive-macos: safari-build-resources
	@echo "Archiving Safari macOS app..."
	xcodebuild -project ${XCODE_PROJECT} \
		-scheme ${XCODE_SCHEME_MACOS} \
		-configuration Release \
		-archivePath ${DERIVED_DATA}/ipvfoo-macos.xcarchive \
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

.PHONY: all prepare firefox chrome safari safari-build-resources safari-ios safari-ios-debug safari-macos safari-macos-debug safari-run-ios safari-run-macos safari-archive-ios safari-archive-macos safari-clean clean
