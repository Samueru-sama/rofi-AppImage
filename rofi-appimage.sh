#!/bin/sh

APP=rofi
APPDIR="$APP.AppDir"
SITE="davatorium/rofi"

# CREATE DIRECTORIES
if [ -z "$APP" ]; then exit 1; fi
mkdir -p ./"$APP" ./"$APP/$APPDIR"/usr/bin ./"$APP/$APPDIR"/usr/share/rofi/themes ./"$APP/$APPDIR"/usr/share/applications && cd ./"$APP" || exit 1

# DOWNLOAD AND BUILD ZENITY
version=$(wget -q https://api.github.com/repos/"$SITE"/releases -O - | grep browser_download_url | grep -i tar.gz | cut -d '"' -f 4 | head -1)
wget "$version" && tar fx ./*tar* || exit 1
#cd ./rofi-* && meson --prefix /usr . build && meson compile -C build || exit 1 # This builds fine in archlinux but can't on ubuntu
cd ./rofi-* && meson --prefix /usr . build && cd ./build && meson compile && cd .. || exit 1 

# PREPARE APPIMAGE FILES
cd .. && mv ./rofi-*/build/rofi ./"$APPDIR"/usr/bin && mv ./rofi-*/script/* ./"$APPDIR"/usr/bin && mv ./rofi-*/themes ./"$APPDIR"/usr/share/rofi && mv ./rofi-*/data/* ./"$APPDIR"
cd ./"$APPDIR" && ln -s ./*.png ./.DirIcon || exit 1 #rofi ships the correct .desktop files already
echo "Categories=Utility;" >> ./rofi.desktop && echo "Categories=Utility;" >> ./rofi-theme-selector.desktop
mv ./rofi-theme-selector.desktop ./usr/share/applications

# AppRun
cat >> ./AppRun << 'EOF'
#!/bin/sh
CURRENTDIR="$(readlink -f "$(dirname "$0")")"
export PATH="$CURRENTDIR/usr/bin:$PATH"
export XDG_DATA_DIRS="/usr/share:$XDG_DATA_DIRS" # This is needed because otherwise rofi-theme-selector breaks

if [ ! -d "$XDG_DATA_HOME/rofi/themes" ] && [ ! -d "$HOME/.local/share/rofi/themes" ]; then
	if [ "$1" = "--install-themes" ]; then
		if [ -n "$XDG_DATA_HOME" ]; then
			mkdir -p "$XDG_DATA_HOME/rofi"
			cp -r "$CURRENTDIR/usr/share/rofi/themes" "$XDG_DATA_HOME/rofi/themes"
		else
			mkdir -p "$HOME/.local/share/rofi"
			cp -r "$CURRENTDIR/usr/share/rofi/themes" "$HOME/.local/share/rofi/themes"
		fi
	else
		echo "No rofi themes directory found" & notify-send "No rofi themes directory found"
		echo "run rofi --install-themes to add them to ~/.local/share/rofi or XDG_DATA_HOME/rofi" 
	fi
fi

if [ "$1" = "rofi-theme-selector" ]; then
	"$CURRENTDIR/usr/bin/rofi-theme-selector"
fi

"$CURRENTDIR/usr/bin/rofi" "$@"
EOF
chmod a+x ./AppRun

# MAKE APPIMAGE
cd ..
APPIMAGETOOL=$(wget -q https://api.github.com/repos/probonopd/go-appimage/releases -O - | grep -v zsync | grep -i continuous | grep -i appimagetool | grep -i x86_64 | grep browser_download_url | cut -d '"' -f 4 | head -1)
wget -q "$APPIMAGETOOL" -O ./appimagetool && chmod a+x ./appimagetool

# Do the thing!
ARCH=x86_64 VERSION=$(./appimagetool -v | grep -o '[[:digit:]]*') ./appimagetool -s ./$APPDIR
ls ./*.AppImage || { echo "appimagetool failed to make the appimage"; exit 1; }

APPNAME=$(ls *AppImage)
APPVERSION=$(echo $version | awk -F / '{print $(NF-1)}')
mv ./*AppImage ./"$APPVERSION"-"$APPNAME"
if [ -z "$APP" ]; then exit 1; fi # Being extra safe lol
mv ./*.AppImage .. && cd .. && rm -rf "./$APP"
echo "All Done!"
