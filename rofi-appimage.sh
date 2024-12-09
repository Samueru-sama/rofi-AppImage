#!/bin/sh

set -eu

APP=rofi
export ARCH="$(uname -m)"
export APPIMAGE_EXTRACT_AND_RUN=1

UPINFO="gh-releases-zsync|$(echo "$GITHUB_REPOSITORY" | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
LIB4BN="https://raw.githubusercontent.com/VHSgunzo/sharun/refs/heads/main/lib4bin"
APPIMAGETOOL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"

# CREATE DIRECTORIES
mkdir -p ./"$APP/AppDir" 
cd ./"$APP/AppDir"

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
chmod +x ./lib4bin
./lib4bin -p -v -r -s ./bin/*
rm -f ./lib4bin

# Add gio modules
cp -rv /usr/lib/gio ./shared/lib
# sharun will not add empty dirs to libs.path
[ -n "$(ls -A ./shared/lib/gio/modules)" ] || touch ./shared/lib/gio/modules/kek.so

# DEPLOY GDK
echo "Deploying gdk..."
GDK_PATH="$(find /usr/lib -type d -regex ".*/gdk-pixbuf-2.0" -print -quit)"
cp -rv "$GDK_PATH" ./shared/lib
echo "Deploying gdk deps..."
find ./shared/lib/gdk-pixbuf-2.0 -type f -name '*.so*' -exec ldd {} \; \
	| awk -F"[> ]" '{print $4}' | xargs -I {} cp -vn {} ./shared/lib
find ./shared/lib -type f -regex '.*gdk.*loaders.cache' \
	-exec sed -i 's|/.*lib.*/gdk-pixbuf.*/.*/loaders/||g' {} \;

# DESKTOP & ICON
find ./ -type f -regex ".*/applications/.*\.desktop" -exec cp {} ./ \;
rm -f ./rofi-theme-selector.desktop || true
find ./ -type f -regex ".*/icons/.*\.\(svg\|png\)" -exec cp {} ./ \;
ln -s ./*.svg ./.DirIcon

echo "Categories=Utility;" >> ./rofi.desktop

# AppRun
cat >> ./AppRun << 'EOF'
#!/usr/bin/env sh
CURRENTDIR="$(dirname "$(readlink -f "$0")")"
DATADIR="${XDG_DATA_HOME:-$HOME/.local/share}"
export PATH="$CURRENTDIR/bin:$PATH"
[ -z "$XDG_DATA_DIRS" ] && XDG_DATA_DIRS="/usr/local/share:/usr/share"
export XDG_DATA_DIRS="$DATADIR:$XDG_DATA_DIRS"
BIN="${ARGV0#./}"
unset ARGV0

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
./sharun -g
export VERSION="$(./AppRun -v | awk 'FNR==1 {print $2; exit}')"
echo "$VERSION" > ~/version

# MAKE APPIMAGE WITH FUSE3 COMPATIBLE APPIMAGETOOL
cd ..
wget -q "$APPIMAGETOOL" -O ./appimagetool
chmod +x ./appimagetool
echo "Generating AppImage..."
./appimagetool --comp zstd \
	--mksquashfs-opt -Xcompression-level --mksquashfs-opt 22 \
	-n -u "$UPINFO" "$PWD"/AppDir "$PWD"/"$APP"-"$VERSION"-anylinux-"$ARCH".AppImage

mv ./*.AppImage* ../
cd ..
rm -rf ./"$APP"
echo "All Done!"
