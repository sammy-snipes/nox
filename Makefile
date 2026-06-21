.PHONY: gen open build run-16 device site deploy

SIM    ?= iPhone 16e
PROJ   := ios/Nox.xcodeproj
SCHEME := Nox
APP_ID := com.samuelellis.nox

# regenerate the Xcode project from project.yml (brew install xcodegen)
gen:
	cd ios && xcodegen generate

# open in Xcode
open:
	open $(PROJ)

# headless compile check against the simulator (catches Swift/API errors, no install)
build:
	xcodebuild -project $(PROJ) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=iOS Simulator,name=$(SIM)' build

# build + install + launch on the simulator
# NOTE: Family Controls is inert on the sim — auth fails, nothing shields.
# Good for UI/compile only; real testing needs `make device`.
run-16:
	xcrun simctl boot "$(SIM)" 2>/dev/null; \
	xcodebuild -project $(PROJ) -scheme $(SCHEME) -configuration Debug \
		-destination 'platform=iOS Simulator,name=$(SIM)' build && \
	xcrun simctl install "$(SIM)" "$$(find ~/Library/Developer/Xcode/DerivedData -name 'Nox.app' -path '*/Debug-iphonesimulator/*' | head -1)" && \
	xcrun simctl launch "$(SIM)" $(APP_ID)

# build + install + launch on the first connected physical device
# (Family Controls works here; needs a signing team set on the target)
device:
	xcodebuild -project $(PROJ) -scheme $(SCHEME) -configuration Debug \
		-destination 'generic/platform=iOS' -allowProvisioningUpdates build && \
	xcrun devicectl device install app --device "$$(xcrun devicectl list devices 2>/dev/null | awk 'NR==3{print $$3}')" \
		"$$(find ~/Library/Developer/Xcode/DerivedData -name 'Nox.app' -path '*/Debug-iphoneos/*' | head -1)"

# preview the nox.church landing page at http://localhost:4242
site:
	cd site && python3 -m http.server 4242

# deploy the landing page to the droplet (nox.church -> /var/www/nox)
deploy:
	rsync -avz --delete site/ droplet:/var/www/nox/
	@echo "deployed -> https://nox.church"
