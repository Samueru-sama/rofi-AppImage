#!/bin/sh

APP=rofi
APPDIR="$APP.AppDir"
SITE="davatorium/rofi"

# CREATE DIRECTORIES
if [ -z "$APP" ]; then exit 1; fi
mkdir -p ./"$APP/$APPDIR" && cd ./"$APP/$APPDIR" || exit 1

# DOWNLOAD AND BUILD ROFI
CURRENTDIR="$(readlink -f "$(dirname "$0")")" # DO NOT MOVE THIS
version=$(wget -q https://api.github.com/repos/"$SITE"/releases -O - | sed 's/"/ /g; s/ /\n/g' | grep -o 'https.*rofi.*releases.*rofi.*tar.gz$' | head -1)
wget "$version" && tar fx ./*tar* && cd ./rofi-* && meson --prefix "$CURRENTDIR" . build && meson compile -C build && meson install -C build || exit 1
cd .. && find ./bin/rofi -type f -executable -exec sed -i -e "s|/usr|././|g" {} \; && sed -i '44,68d; s/DIRS=\${XDG_DATA_DIRS}//' ./bin/rofi-theme-selector && rm -rf ./rofi-*

# ROFI EMOJI DOESN'T COMPILE!!!
#git clone https://github.com/Mange/rofi-emoji.git && cd ./rofi-emoji && autoreconf -i && ./configure --prefix="$CURRENTDIR" && make && make install || exit 1

# DESKTOP & ICON
echo "Categories=Utility;" >> ./share/applications/rofi.desktop && echo "Categories=Utility;" >> ./share/applications/rofi-theme-selector.desktop
cp ./share/applications/rofi.desktop ./"$APP".desktop && cp ./share/icons/*/*/*/* ./$APP.svg && ln -s ./*.svg ./.DirIcon || exit 1

# AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
CURRENTDIR="$(readlink -f "$(dirname "$0")")"
DATADIR="${XDG_DATA_HOME:-$HOME/.local/share}"
export PATH="$PATH:$CURRENTDIR/bin"
export XDG_DATA_DIRS="$CURRENTDIR/share:/usr/share:$XDG_DATA_DIRS"

if [ ! -d "$DATADIR/rofi/themes" ]; then
	if [ "$1" = "--install-themes" ]; then
		mkdir -p "$DATADIR/rofi" && cp -r "$CURRENTDIR/share/rofi/themes" "$DATADIR/rofi/themes"
	else
		echo "No rofi themes directory found" & notify-send "No rofi themes directory found"
		echo 'run rofi --install-themes to add them to ~/.local/share/rofi or $XDG_DATA_HOME/rofi'
	fi
fi

if [ "$1" = "rofi-theme-selector" ]; then
	"$CURRENTDIR/bin/rofi-theme-selector"
fi

"$CURRENTDIR/bin/rofi" "$@"
EOF
chmod a+x ./AppRun
APPVERSION=$(echo $version | awk -F / '{print $(NF-1)}')

# MAKE APPIMAGE
APPIMAGETOOL=$(wget -q https://api.github.com/repos/probonopd/go-appimage/releases -O - | sed 's/"/ /g; s/ /\n/g' | grep -o 'https.*continuous.*tool.*86_64.*mage$')
cd .. && wget -q "$APPIMAGETOOL" -O ./appimagetool && chmod a+x ./appimagetool || exit 1

# Do the thing!
ARCH=x86_64 VERSION="$APPVERSION" ./appimagetool -s ./"$APPDIR"
ls ./*.AppImage || { echo "appimagetool failed to make the appimage"; exit 1; }
if [ -z "$APP" ]; then exit 1; fi # Being extra safe lol
mv ./*.AppImage .. && cd .. && rm -rf "./$APP"
echo "All Done!"
