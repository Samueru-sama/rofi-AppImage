#!/bin/sh
set -eu
APP=rofi
APPDIR="$APP.AppDir"
SITE="davatorium/rofi"
EXEC="$APP"
export ARCH="$(uname -m)"
APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
SHARUN="https://bin.ajam.dev/$ARCH/sharun"

# CREATE DIRECTORIES
mkdir -p ./"$APP/$APPDIR" && cd ./"$APP/$APPDIR" || exit 1

# DOWNLOAD AND BUILD ROFI
CURRENTDIR="$(dirname "$(readlink -f "$0")")" # DO NOT MOVE THIS
git clone https://github.com/davatorium/rofi.git ./rofi
cd ./rofi
meson --prefix "$CURRENTDIR/usr" . build
meson compile -C build && meson install -C build
cd ..
sed -i '44,68d; s/DIRS=\${XDG_DATA_DIRS}//' ./usr/bin/rofi-theme-selector
rm -rf ./rofi

# ADD LIBRARIES
mv ./usr/bin ./
wget "$LIB4BN" -O ./lib4bin && wget "$SHARUN" -O ./sharun
chmod +x ./lib4bin ./sharun
HARD_LINKS=1 ./lib4bin ./bin/*
rm -f ./lib4bin

# DESKTOP & ICON
find ./ -type f -regex ".*/applications/.*\.desktop" -exec cp {} ./ \;
rm -f ./rofi-theme-selector.desktop || true
find ./ -type f -regex ".*/icons/.*\.\(svg\|png\)" -exec cp {} ./ \;
ln -s ./*.svg ./.DirIcon

echo "Categories=Utility;" >> ./rofi.desktop

# AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
CURRENTDIR="$(dirname "$(readlink -f "$0")")"
DATADIR="${XDG_DATA_HOME:-$HOME/.local/share}"
export PATH="$CURRENTDIR/bin:$PATH"
export XDG_DATA_DIRS="$CURRENTDIR/usr/share:/usr/share:$XDG_DATA_DIRS"

if [ ! -d "$DATADIR/rofi/themes" ]; then
	mkdir -p "$DATADIR/rofi" || exit 1
	if ! cp -rn "$CURRENTDIR/usr/share/rofi/themes" "$DATADIR/rofi/themes"; then
		echo "No rofi themes directory found"
		echo "Something went wrong because the AppImage should have copied them"
		echo "to "$DATADIR/rofi/themes""
		notify-send "No rofi themes directory found"
	fi
fi

if [ "$1" = "rofi-theme-selector" ]; then
	"$CURRENTDIR/bin/rofi-theme-selector"
fi

exec "$CURRENTDIR/bin/rofi" "$@"
EOF
chmod a+x ./AppRun
export VERSION="$(./AppRun -v | awk 'FNR==1 {print $2; exit}')"
cd ..

# MAKE APPIAMGE WITH FUSE3 COMPATIBLE APPIMAGETOOL
APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
wget -q "$APPIMAGETOOL" -O ./appimagetool && chmod a+x ./appimagetool || exit 1
rm -f ./"$APPDIR"/rofi-theme-selector* # Why does this get created?

# Do the thing!
./appimagetool --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 20 \
	-n -u "gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|rofi-AppImage|continuous|*$ARCH.AppImage.zsync" \
	./"$APP".AppDir Rofi-"$VERSION"-"$ARCH".AppImage
[ -n "$APP" ] && mv ./*.AppImage* .. && cd .. && rm -rf ./"$APP" || exit 1
echo "All Done!"
