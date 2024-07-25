#!/bin/sh
set -u
APP=rofi
APPDIR="$APP.AppDir"
SITE="davatorium/rofi"
EXEC="$APP"

# CREATE DIRECTORIES
if [ -z "$APP" ]; then exit 1; fi
mkdir -p ./"$APP/$APPDIR" && cd ./"$APP/$APPDIR" || exit 1

# DOWNLOAD AND BUILD ROFI
CURRENTDIR="$(dirname "$(readlink -f "$0")")" # DO NOT MOVE THIS
git clone https://github.com/davatorium/rofi.git && cd ./rofi \
&& meson --prefix "$CURRENTDIR/usr" . build && meson compile -C build && meson install -C build || exit 1
cd .. && sed -i '44,68d; s/DIRS=\${XDG_DATA_DIRS}//' ./usr/bin/rofi-theme-selector && rm -rf ./rofi

# DESKTOP & ICON
echo "Categories=Utility;" >> ./usr/share/applications/rofi.desktop && echo "Categories=Utility;" >> ./usr/share/applications/rofi-theme-selector.desktop
cp ./usr/share/applications/rofi.desktop ./"$APP".desktop && cp ./usr/share/icons/*/*/*/* ./$APP.svg && ln -s ./*.svg ./.DirIcon || exit 1

# AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
CURRENTDIR="$(dirname "$(readlink -f "$0")")"
DATADIR="${XDG_DATA_HOME:-$HOME/.local/share}"
export PATH="$PATH:$CURRENTDIR/bin"
export XDG_DATA_DIRS="$CURRENTDIR/usr/share:/usr/share:$XDG_DATA_DIRS"
export LD_LIBRARY_PATH="/lib:$CURRENTDIR/usr/lib"

if [ ! -d "$DATADIR/rofi/themes" ]; then
	if [ "$1" = "--install-themes" ]; then
		mkdir -p "$DATADIR/rofi" && cp -r "$CURRENTDIR/usr/share/rofi/themes" "$DATADIR/rofi/themes"
	else
		echo "No rofi themes directory found" & notify-send "No rofi themes directory found"
		echo 'run rofi --install-themes to add them to ~/.local/share/rofi or $XDG_DATA_HOME/rofi'
	fi
fi

if [ "$1" = "rofi-theme-selector" ]; then
	"$CURRENTDIR/bin/rofi-theme-selector"
fi

"$CURRENTDIR/usr/bin/rofi" "$@"
EOF
chmod a+x ./AppRun
APPVERSION=$(./AppRun -v | awk 'FNR==3 {print $2}')

# MAKE APPIMAGE
LINUXDEPLOY="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-static-x86_64.AppImage"
cd .. && wget "$LINUXDEPLOY" -O linuxdeploy && chmod a+x ./linuxdeploy && ./linuxdeploy --appdir "$APPDIR" --executable "$APPDIR"/usr/bin/"$EXEC" --output appimage

# LIBFUSE3
APPIMAGETOOL=$(wget -q https://api.github.com/repos/probonopd/go-appimage/releases -O - | sed 's/[()",{} ]/\n/g' | grep -oi 'https.*continuous.*tool.*x86_64.*mage$' | head -1)

[ -n "$APPDIR" ] && ls *AppImage && rm -rf ./"$APPDIR" || exit 1
./*AppImage --appimage-extract && mv ./squashfs-root ./"$APPDIR" && rm -f ./*AppImage && wget -q "$APPIMAGETOOL" -O ./appimagetool && chmod a+x ./appimagetool || exit 1
rm -f ./"$APPDIR"/rofi-theme-selector* # Why does this get created?

# Do the thing!
ARCH=x86_64 VERSION="$APPVERSION" ./appimagetool -s ./"$APPDIR" || exit 1
[ -n "$APP" ] && mv ./*.AppImage .. && cd .. && rm -rf ./"$APP" && echo "All Done!" || exit 1
