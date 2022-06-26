# REFramework-Scripts

This is a repository of my RE Engine Lua script mods for use with REFramework. The scripts are meant to work in all RE Engine games.
Download REFramework from https://github.com/praydog/REFramework-nightly/releases

## Installation
All scripts require REFramework's dinput8.dll to be in your game directory, and all of my scripts require EMV Engine.lua.
Scripts can be installed each as a package by Fluffy Mod Manager. Simply put the script's folder from this repository into your game's Mods folder in your Fluffy Mod Manager directory and install like any other mod.
Alternatively, they can be installed or run manually by placing them in your game directory's reframework/autorun folder, or by running them manually with "Run Script" under REFramework's "ScriptRunner" UI.

## EMV Engine
EMV Engine is a lua script containing many useful utility functions and features that all my other scripts rely on.
You must install this script first to use any of my other scripts.

## Enhanced Model Viewer
Enhanced Model Viewer is an animation and cutscene viewer that allows you to control animations and sequences in real time. 
It will appear automatically inside the model viewers of RE2R, RE3R, DMC5 and RE8, as well as in the cutscenes of RE2R, RE3R and DMC5.

## Console
This script creates an interactive Lua Console in the game, for use in researching the game engine and testing Lua code. 
It has access to all global variables and a variety of useful functions from EMV Engine.

## Gravity Gun
The Gravity Gun allows you to manipulate 3D objects using the camera and the mouse. 
Hold middle mouse button to fire a beam that detects the closest collidable object to the camera, and grabs it when you let go.
Roll the mouse in and out to reel the object in or push it away.

## Enemy Spawner
This script for RE2R and RE3R allows you to spawn enemies at the last location that the Gravity gun was fired at.

### Thanks to praydog for making REFramework and for all the guidance in making these scripts
* These scripts are each a work-in-progress and may have bugs across the various game and engine versions