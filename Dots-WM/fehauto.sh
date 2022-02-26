#Random wallpaper

#One neat trick available with feh is a random wallpaper on each boot. 
#Create a directory in your home folder called "wallpapers" and put a few
#background images into it. Then copy the code below into a file called 
#wallpaper.sh and save it anywhere. A good place is ~/.config/openbox



 #! /usr/bin/env sh
 WALLPAPERS="/home/juca/Pictures/Wallpapers"

 desktop_bg=$(find "$WALLPAPERS" -type f | shuf | head -n 1) &&
 exec feh --bg-scale "$desktop_bg"

#Next, make the script executable.


#chmod +x wallpaper.sh
#Now add that program to the autostart.sh file, like this.


#Random wallpaper
#./pathFromHome/wallpaper.sh
