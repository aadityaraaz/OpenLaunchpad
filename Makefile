.PHONY: build test app run release
build:
	swift build
test:
	./scripts/test.sh
app:
	./scripts/build-app.sh
run: app
	open dist/OpenLaunchpad.app
release:
	./scripts/package-release.sh
