.PHONY: build run install clean

build:
	@scripts/build.sh

run: build
	@open build/SpotifyMenuBar.app

install: build
	@scripts/install.sh

clean:
	@rm -rf .build build
