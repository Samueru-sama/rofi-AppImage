# rofi-AppImage

Unofficial AppImage of [rofi](https://github.com/davatorium/rofi)

Includes the default themes which get installed by running `./appimagename --install-themes` provided there is no rofi themes directory in `$XDG_CONFIG_HOME/rofi/themes` or `~/.local/share/rofi/themes`

rofi-theme-selector is called this way: `./appimagename rofi-theme-selector`. 

You can also run the `rofi-appimage.sh` script in your machine to make the AppImage, provided it has all the dependencies needed to build rofi (which good luck with that btw).

It is possible that these appimages may fail to work with appimagelauncher, since appimagelauncher is pretty much dead I recommend this alternative: https://github.com/ivan-hc/AM

This appimage works without fuse2 as it can use fuse3 instead.

# TODO
Find a way to bundle rofi-emoji into the appimage
