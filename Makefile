.PHONY: build test run app icon keys clean

TEST_PLUGIN_FLAGS = -Xswiftc -load-plugin-library -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib

build:
	swift build -c release

# CLT toolchains ship the Swift Testing macro plugin in a subdirectory that
# swift-frontend does not search by default; load it explicitly.
test:
	swift test $(TEST_PLUGIN_FLAGS)

run:
	swift run Pasteback

app: icon
	scripts/build-app.sh release

icon:
	scripts/make-icon.sh

keys:
	swift scripts/generate_update_keys.swift | tee Resources/SparklePublicED.key

clean:
	swift package clean
	rm -rf dist
