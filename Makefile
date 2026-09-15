.PHONY: build run install dmg clean

build:
	@scripts/build.sh

run: build
	@open build/SpotifyMenuBar.app

install: build
	@scripts/install.sh

dmg:
	@scripts/dmg.sh

clean:
	@rm -rf .build build
