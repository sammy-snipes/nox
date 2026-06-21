.PHONY: gen open

# regenerate the Xcode project from project.yml (requires: brew install xcodegen)
gen:
	cd ios && xcodegen generate

# open the project in Xcode
open:
	open ios/Nox.xcodeproj
