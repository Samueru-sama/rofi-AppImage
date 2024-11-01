#!/bin/sh
set -eu
APP=rofi
APPDIR="$APP.AppDir"
export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1
APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
SHARUN="https://bin.ajam.dev/$ARCH/sharun"

# CREATE DIRECTORIES
mkdir -p ./"$APP/$APPDIR" && cd ./"$APP/$APPDIR" || exit 1

# DOWNLOAD AND BUILD ROFI
CURRENTDIR="$(dirname "$(readlink -f "$0")")" # DO NOT MOVE THIS
git clone --depth 1 "https://github.com/davatorium/rofi.git" ./rofi
cd ./rofi
meson --prefix "$CURRENTDIR/usr" . build
meson compile -C build && meson install -C build
cd ..
rm -rf ./rofi

# ADD LIBRARIES
mv ./usr/bin ./
wget "$LIB4BN" -O ./lib4bin
wget "$SHARUN" -O ./sharun
chmod +x ./lib4bin ./sharun
HARD_LINKS=1 ./lib4bin ./bin/*
rm -f ./lib4bin

# DEPLOY GDK
echo "Deploying gdk..."
GDK_PATH="$(find /usr/lib -type d -regex ".*/gdk-pixbuf-2.0" -print -quit)"
cp -rv "$GDK_PATH" ./shared/lib
echo "Deploying gdk deps..."
find ./shared/lib/gdk-pixbuf-2.0 -type f -name '*.so*' -exec ldd {} \; \
	| awk -F"[> ]" '{print $4}' | xargs -I {} cp -vn {} ./shared/lib
find ./shared/lib -type f -regex '.*gdk.*loaders.cache' \
	-exec sed -i 's|/.*lib.*/gdk-pixbuf.*/.*/loaders/||g' {} \;
( cd ./shared/lib && find ./gdk-pixbuf-2.0 -type f -name '*.so*' -exec ln -s {} ./ \; )

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
[ -z "$XDG_DATA_DIRS" ] && XDG_DATA_DIRS="/usr/local/share:/usr/share"
export XDG_DATA_DIRS="$DATADIR:$XDG_DATA_DIRS"
export GIO_MODULE_DIR="$CURRENTDIR"
BIN="${ARGV0#./}"
unset ARGV0

GDK_HERE="$(find "$CURRENTDIR" -type d -regex '.*gdk.*loaders' -print -quit)"
GDK_LOADER="$(find "$CURRENTDIR" -type f -regex '.*gdk.*loaders.cache' -print -quit)"
export GDK_PIXBUF_MODULEDIR="$GDK_HERE"
export GDK_PIXBUF_MODULE_FILE="$GDK_LOADER"

if [ ! -d "$DATADIR/rofi/themes" ]; then
	mkdir -p "$DATADIR/rofi" || exit 1
	if ! cp -rn "$CURRENTDIR/usr/share/rofi/themes" "$DATADIR/rofi/themes"; then
		echo "No rofi themes directory found"
		echo "Something went wrong because the AppImage should have copied them"
		echo "to \"$DATADIR/rofi/themes\""
		notify-send "No rofi themes directory found"
	fi
fi

if [ "$1" = "rofi-theme-selector" ]; then
	shift
	exec "$CURRENTDIR/bin/rofi-theme-selector" "$@"
elif [ -f "$CURRENTDIR/bin/$BIN" ]; then
	exec "$CURRENTDIR/bin/$BIN" "$@"
else
	exec "$CURRENTDIR/bin/rofi" "$@"
fi
EOF
chmod a+x ./AppRun
export VERSION="$(./AppRun -v | awk 'FNR==1 {print $2; exit}')"
cd ..

# MAKE APPIAMGE WITH FUSE3 COMPATIBLE APPIMAGETOOL
wget -q "$APPIMAGETOOL" -O ./appimagetool && chmod a+x ./appimagetool || exit 1

ls
# Do the thing!
./appimagetool --comp zstd --mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
	-n -u "gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|rofi-AppImage|continuous|*$ARCH.AppImage.zsync" \
	./"$APP".AppDir Rofi-"$VERSION"-"$ARCH".AppImage
[ -n "$APP" ] && mv ./*.AppImage* .. && cd .. && rm -rf ./"$APP" || exit 1
echo "All Done!"
