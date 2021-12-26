#!/bin/bash
echo 	
echo	"/* ******************************************* */"
echo	"/*                                             */"
echo	"/*  	ELEMENTARY OS 6.1 DESKTOP FOLDER        */"
echo	"/*               INSTALLER V1.0                */"
echo	"/*                                             */"
echo	"/* ******************************************* */"
echo
echo "### APT UPDATE ###"
echo
sudo apt update
echo
echo "### INSTALL PACKAGES ###"
sudo apt install meson valac libgee-0.8-dev libcairo2-dev libjson-glib-dev libgdk-pixbuf2.0-dev libwnck-3-dev libgtksourceview-3.0-dev libjson-glib-dev intltool libgranite-dev
echo
echo "### MESON BUILD ###"
echo
meson build
echo
echo "### START COMPILE ###"
echo
cd build
meson configure -D prefix=/usr
echo
ninja
echo
echo "### INSTALL ###"
sudo ninja install
./com.github.spheras.desktopfolder
