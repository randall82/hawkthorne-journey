.PHONY: clean contributors run forum productionize deploy love maps

UNAME := $(shell uname)

ifeq ($(UNAME), Darwin)
  TMXTAR = tmx2lua.osx.tar
  LOVE = bin/love.app/Contents/MacOS/love
else
  TMXTAR = tmx2lua.linux.tar
  LOVE = /usr/bin/love
endif

ifeq ($(shell which wget),)
  wget = curl -O -L
else
  wget = wget --no-check-certificate
endif

tilemaps := $(patsubst %.tmx,%.lua,$(wildcard src/maps/*.tmx))

maps: $(tilemaps)

love: build/hawkthorne.love

build/hawkthorne.love: $(tilemaps) src/*
	mkdir -p build
	cd src && zip --symlinks -q -r ../build/hawkthorne.love . -x ".*" \
		-x ".DS_Store" -x "*/full_soundtrack.ogg" -x "*.bak"

run: $(tilemaps) $(LOVE)
	$(LOVE) src

src/maps/%.lua: src/maps/%.tmx bin/tmx2lua
	bin/tmx2lua $<

bin/tmx2lua:
	mkdir -p bin
	$(wget) http://hawkthorne.github.com/tmx2lua/downloads/$(TMXTAR)
	tar -xvf $(TMXTAR)
	rm -f $(TMXTAR)
	mv tmx2lua bin

bin/love.app/Contents/MacOS/love:
	mkdir -p bin
	$(wget) https://bitbucket.org/kyleconroy/love/downloads/love-sparkle.zip
	unzip -q love-sparkle.zip
	rm -f love-sparkle.zip
	mv love.app bin
	cp osx/dsa_pub.pem bin/love.app/Contents/Resources
	cp osx/Info.plist bin/love.app/Contents

/usr/bin/love:
	sudo add-apt-repository ppa:bartbes/love-stable
	sudo apt-get update
	sudo apt-get install love

######################################################
# THE REST OF THESE TARGETS ARE FOR RELEASE AUTOMATION
######################################################

CI_TARGET=test validate maps

ifeq ($(TRAVIS), true)
ifeq ($(TRAVIS_BRANCH), release)
ifeq ($(TRAVIS_PULL_REQUEST), false)
CI_TARGET=clean test validate maps productionize upload deltas social
endif
endif
endif

positions: $(patsubst %.png,%.lua,$(wildcard src/positions/*.png))

src/positions/%.lua: psds/positions/%.png
	overlay2lua src/positions/config.json $<

build/hawkthorne-win-x86.zip: build/hawkthorne.love
	mkdir -p build
	rm -rf hawkthorne
	rm -f hawkthorne-win-x86.zip
	cat win32/love.exe build/hawkthorne.love > win32/hawkthorne.exe
	cp -r win32 hawkthorne
	zip --symlinks -q -r hawkthorne-win-x86 hawkthorne -x "*/love.exe"
	mv hawkthorne-win-x86.zip build

win32/love.exe:
	$(wget) https://bitbucket.org/kyleconroy/love/downloads/windows-build-files.zip
	unzip -q windows-build-files.zip
	rm -f windows-build-files.zip

build/hawkthorne-win-x64.zip: build/hawkthorne.love
	mkdir -p build
	rm -rf hawkthorne
	rm -f hawkthorne-win-x64.zip
	cat win64/love.exe build/hawkthorne.love > win64/hawkthorne.exe
	cp -r win64 hawkthorne
	zip --symlinks -q -r hawkthorne-win-x64 hawkthorne -x "*/love.exe"
	mv hawkthorne-win-x64.zip build

build/hawkthorne-osx.zip: bin/love.app/Contents/MacOS/love $(tilemaps) src/*
	mkdir -p build
	cp -R bin/love.app Journey\ to\ the\ Center\ of\ Hawkthorne.app
	cp -r src Journey\ to\ the\ Center\ of\ Hawkthorne.app/Contents/Resources/hawkthorne.love
	rm -f Journey\ to\ the\ Center\ of\ Hawkthorne.app/Contents/Resources/hawkthorne.love/.DS_Store
	cp osx/Info.plist \
		Journey\ to\ the\ Center\ of\ Hawkthorne.app/Contents/Info.plist
	cp osx/Hawkthorne.icns \
		Journey\ to\ the\ Center\ of\ Hawkthorne.app/Contents/Resources/Love.icns
	zip --symlinks -q -r hawkthorne-osx Journey\ to\ the\ Center\ of\ Hawkthorne.app
	mv hawkthorne-osx.zip build
	rm -rf Journey\ to\ the\ Center\ of\ Hawkthorne.app

productionize: venv
	venv/bin/python scripts/productionize.py

binaries: build/hawkthorne-osx.zip build/hawkthorne-win-x64.zip build/hawkthorne-win-x86.zip

upload: binaries venv
	venv/bin/python scripts/upload_binaries.py

deltas: venv
	venv/bin/python scripts/sparkle.py
	cat sparkle/appcast.xml | xmllint -format - # Make sure the appcast is valid xml
	venv/bin/python scripts/upload.py / sparkle/appcast.xml

social: venv post.md notes.html
	venv/bin/python scripts/upload_release_notes.py
	venv/bin/python scripts/socialize.py post.md

notes.html: post.md
	venv/bin/python -m markdown post.md > notes.html

post.md:
	venv/bin/python scripts/create_post.py post.md

venv:
	virtualenv -q --python=python2.7 venv
	venv/bin/pip install -q -r requirements.txt

deploy: $(CI_TARGET)

forum: venv
	venv/bin/python scripts/create_forum_post.py

contributors: venv
	venv/bin/python scripts/clean.py > CONTRIBUTORS
	venv/bin/python scripts/credits.py > src/credits.lua

test:
	busted spec

validate: venv
	venv/bin/python scripts/validate.py src

clean:
	rm -rf build
	rm -f release.md
	rm -f post.md
	rm -f notes.html
	rm -rf src/maps/*.lua
	rm -rf Journey\ to\ the\ Center\ of\ Hawkthorne.app

reset:
	rm -rf ~/Library/Application\ Support/LOVE/hawkthorne/*.json
	rm -rf $(XDG_DATA_HOME)/love/ ~/.local/share/love/
	rm -rf src/maps/*.lua
