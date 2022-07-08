# REFramework-Scripts

This is a repository of my RE Engine Lua script mods for use with praydog and Cursey's "REFramework". 
The scripts are meant to work in all RE Engine games.
Download REFramework from https://github.com/praydog/REFramework-nightly/releases

## Installation
All scripts require REFramework's dinput8.dll to be in your game directory, and all of my scripts require EMV Engine's init.lua.
Scripts can be installed each as a package by Fluffy Mod Manager. Simply put the script's folder from this repository into your game's Mods folder in your Fluffy Mod Manager directory and install like any other mod.
Alternatively, they can be installed or run manually by placing them in your game directory's reframework/autorun folder, or by running them manually with "Run Script" under REFramework's "ScriptRunner" UI.

## EMV Engine
EMV Engine is a lua script containing many useful utility functions and features that all my other scripts rely on.
Features
* Imgui Managed Object Control Panel: Views game objects as control panels of their fields and properties, embedding other tools inside
* Material Manager: Edit all MDF Material settings and textures live and in-engine
* Poser: Rotates and freezes joints to pose models for screenshots
* Action Monitor: Controls FSM actions and behaviors. Includes a WIP Sequencer
* Chain Controller: Visualizes chains and view "CustomSettings" Chain physics settings
* Hotkey Manager: Allows you to set an entity action as a hotkey
### You must install EMV Engine first to use any of my other scripts, which require "EMV Engine\init.lua" to be available

## Enhanced Model Viewer
Enhanced Model Viewer is an animation and cutscene viewer that allows you to control animations and sequences in real time. 
It will appear automatically inside the model viewers of RE2R, RE3R, DMC5 and RE8, as well as in the cutscenes of RE2R, RE3R and DMC5.
Additionally, you can force the animation viewer to appear on most animatable objects by clicking "Enable Animation Viewer" button when viewing their object in the Managed Object Control Panels created by EMV Engine.

## Gravity Gun
The Gravity Gun allows you to manipulate 3D objects using the camera and the mouse. Thanks to praydog for creating the initial version.
Hold middle mouse button to fire a beam that detects the closest collidable object to the camera, and grabs it when you let go.
Roll the mouse in and out to reel the object in or push it away.

## Enemy Spawner
This script for RE2R and RE3R allows you to spawn enemies at the last location that the Gravity gun was aimed at.
You can also spawn PFB files. A drop down menu will appear to let you spawn any PFB file you've seen, or one you input.

## Console
This script creates an interactive Lua Console in the game, for use in researching the game engine and testing Lua code. 
It has access to a variety of useful functions from EMV Engine as well as all global variables across all running scripts. 
This makes the console useful for debugging scripts, since you can just make your variables global to check their values in the console.
### Console Commands / Features:
* Press tab or the blank button after the "Enter" button to auto-complete, like in a terminal or command prompt
* Type'/' followed by some text to search the game world for objects with that text in their names
* Type 'transforms' to get a list of all objects in the game world, ordered by creation
* Execute multiple lines of code within the console by using semicolons to separate statements
* Use '=' to make assignments within for loops inside your Console commands, or ' = ' to make a one-line assignment and view the result

### Thanks to praydog for making REFramework and for all the guidance
* These scripts are each a work-in-progress and may have bugs across the various game and engine versions
