# EMV-Engine (REFramework-Scripts)

This is a repository of my RE Engine Lua script mods, for use with [praydog](https://github.com/praydog) and [Cursey](https://github.com/cursey)'s "REFramework"   
### Supported Games
* Devil May Cry 5
* Resident Evil 7
* Resident Evil 8
* Resident Evil 2 Remake
* Resident Evil 3 Remake
* Monster Hunter Rise: Sunbreak

### Requirements
* [REFramework](https://github.com/praydog/REFramework-nightly/releases)
* [Fluffy Mod Manager (Optional)](https://www.fluffyquack.com/modding/)

### Installation
* All scripts require REFramework's dinput8.dll to be in your game directory, and all of my scripts require "EMV Engine\init.lua"  
* Scripts can be installed each as a package by Fluffy Mod Manager. Simply put the script's folder from this repository into your game's Mods folder in your Fluffy Mod Manager directory and install like any other mod  
* Alternatively, they can be installed or run manually by placing them in your game directory's reframework/autorun folder, or by running them manually with "Run Script" under REFramework's "ScriptRunner" UI  

# EMV Engine Lua Script (Required)
**EMV Engine** is a large Lua script containing many useful utility features and functions that all my other scripts rely on. 
The script does nothing on its own, but is utilized when Enhanced Model Viewer, Gravity Gun, Console or Enemy Spawner are used run.  
![alpha](https://i.imgur.com/2ykqQ8b.jpg)

## Features:  

### Imgui Managed Object Control Panel  
Views GameObjects as control panels of their fields and properties, embedding many other tools inside  
Includes a variety of useful features in imgui for changing object settings, including the ability to: 

* Freeze fields and properties to one value, for when the game keeps changing them back, or reset them to their original values
* Load resources (files) by text input or by a cached list of resources seen by EMV Engine
* Run Simple Methods (that have no arguments or return values) using imgui buttons
* Control positions and rotations of individual fields with interactive 3D gizmos
* Change the parent of a GameObject
* Display a wireframe of a model's joints
* Enable, disable, or destroy GameObjects and Components
* Embeds REFramework's Object Explorer into itself, and can optionally embed itself into the Lua version of Object Explorer inside any other running script
* Save and Load field data of Managed Objects, from individual Components to full GameObjects, optionally with their children (saved GameObjects can be recreated in the "Collection" menu)

<details>
<summary>Click Here for the Imgui Managed Object Control Panel Guide and Screenshots</summary>

* An example of a Managed Object Control Panel, for via.Transform:  
![Imgui Managed Object Control Panel](https://i.imgur.com/5rGLiIr.jpg)
* String values in the format **vec:1.0 0.0 0.0** or **res:[resource path]** are special string representations of vectors, matrices, quaternions and resources. These values can be copy pasted to transfer the real value  
* Certain fields have special capabilities, such as for resources (files). You can click the checkbox to add a new file by typing its path, and other resources will appear in the list as you see them in the control panels.
![Loading Resources](https://i.imgur.com/6MwUsjj.png)
#### Advanced Managed Object Settings
* A tree node titled "**\[Object Explorer\]**" contains advanced settings for a managed object, and displays Object Explorer
* The **Update** button updates all fields of a Managed Object, and the **checkbox** next to it makes it so all Managed Objects of that type will have all their fields updated every frame. This is disabled by default and fields are cached, because this can get expensive with many control panels open  
* **Clear Lua Data** makes the managed object Lua class instance be recreated, refreshing all properties anew
* **Sort Alphabetically** Sorts the fields and properties in alphabetical order
* **Save/Load GameObject** are described in the Collection section below
* **Assign to Console Var: tmp** makes a global variable "tmp" of the managed object that can be used in the console
* **Find all [via.Components]** creates a console command that displays a list of all existing components of the same type as this Managed Object
* The **Mini Console** provides a text input for the console embedded inside the \[Object Explorer\] menu. 
* **Show History** forces the child window of the Mini Console to expand and displays recent commands inside
![Object Exlporer Menu](https://i.imgur.com/RP1Le0N.png)  
#### EMV Engine Settings
* **Remember Settings** makes EMV Engine save and load data from JSON. Many features rely on this
* **Affect Children** makes many settings and features apply to a GameObject and all its children together
* **Cache Ordered Dictionaries** makes it so dictionaries that are sorted alphanumberically are not sorted every frame, improving performance
* **Remember Material Settings** toggles on and off the automatic loading of materials saved with the Material Manager  
![EMV Engine Settings](https://i.imgur.com/ge85DGM.png)
#### via.GameObject / via.Transform / via.Component Tools
* **Enabled** Checkbox lets you enable and disable the managed object (making it disappear and stop working on disable). Be careful using this with important objects, such as the camera.
* The **Destroy** button will delete the managed object or GameObject. Be careful with this as well
* **Enable Animation Viewer** activates Enhanced Model Viewer if it is running, and adds the selected GameObject and its children to its list of animated actors
* The **Set Parent** and **Unset / Reset** buttons let you pick another GameObject to be this GameObject's parent
* **Show Transform** draws text in the game world indicating where a mesh is, visible through walls
* The **Grab** is available when the Gravity Gun is running, and lets you grab the object with the gravity gun
* The **Add to Collection** button is a means for adding new GameObjects to be pinned in the Collection menu
* The **Look-At** checkbox activates lookAt mode, where the transform of the object or one of its bones can be forced to point towards another object
* The **Show Joints** checkbox lets you see the bones of a GameObject from anywhere:  
![Show Joints](https://i.imgur.com/f5vnA1C.png)
* **Show Joint Names** displays the names of each bone when Show Joints is checked.
* **Print Bones Enum** and **Print ChainBones Enum** are special buttons for printing lists of bones and their bone hashes, for use in modding chain and other files  
#### Managed Object Control Panel Settings
* **Max Fields / Properties Per Grouping** specifies the maximum number of list entries that will be displayed together. Groupings will make the fields and properties of large Managed Objects appear as **Elements 1-100, Elements 101-200** etc if the limit is 100  
* **Show Extra Fields** displays Managed Object properties that may be hidden by default, due to being duplicates of fields or having strange behaviors (such as requiring an unknown extra parameter)
* **Embed Into Object Exlplorer (Lua)** makes it so Imgui Managed Object Control Panel is shown as an imgui tree node any place where a script (any script) uses **object_explorer:handle_address()** function, embedding itself into many other scripts
* **Exception Handling** makes it so all field getters and setters used by EMV are called only inside protected function calls, to avoid crashes  
![Managed Object Control Panel Settings](https://i.imgur.com/ebzRgpq.png)
* The **Freeze** and **X** buttons will appear next to recently changed fields, allowing for them to be reset to original value with X or frozen to the set value  
![Freeze](https://i.imgur.com/n9K6rAs.png)
* The **Deferred Method Calls** list shows a record of old function calls that were placed in the queue, showing whether the call was successful and info about the arguments
* Deferred Calls are often re-used every frame by fields and properties whenever they are **Frozen** (constantly set to the same value every frame)  
![Old Deferred Calls](https://i.imgur.com/NyxUIAs.png)
* The **+** menu under a field shows special data about that field, including text inputs, freezing, gizmos for Vectors and resetting values.
* Managed Object values can be assigned to global variable in the **Global Alias** text box
* A global variable can be input under **Assign to Global Var** to set a field with a different Managed Object, if it is the same type of Object  
![Assign to Global Var](https://i.imgur.com/Q5ZsAp3.png)

</details>

### Collection & GameObject Spawner  
* Provides advanced search functionalities and persistent, easy management of GameObjects in the scene  
* The GameObject Spawner lets you construct your own GameObjects from a list of Components, or even spawn ones using the data from from JSON files saved with Imgui Managed Object Control Panel
* Objects in the Collection can be moved and frozen in place with a Gizmo

<details>
<summary>Click Here for Collection & GameObject Spawner Guide and Screenshots</summary>

* **Search** the scene for GameObjects by component, optional components, name, and exclude by name. You can update search results and preserve deleted Collection objects to find them again when they respawn
![Collection Search](https://i.imgur.com/Bme60bB.png)
* An interactive **gizmo** is available as a marker for where to spawn GameObjects and for controlling (and freezing) the position of the currently selected Collection object. Can be moved to the camera and have its rotation reset  
* You can use the Save / Load GameObject buttons in Imgui Managed Object Control Panel's **\[Object Explorer\]** menu to save individual components or full GameObjects with their children to JSON  
![Save Load GameObject Buttons](https://i.imgur.com/Vx060oz.png)
* Use the **GameObject Spawner** to import these same saved settings when creating a new GameObject by checking "Load By Name" and selecting a file
* When creating a GameObject from JSON, be careful not to leave via.motion.Motion enabled, as it will make the character unable to animate  
* Check **Load Only Resources** to only set fields that are for resources (files) in the new GameObject, and "Load Children" to load multiple GameObjects comprising a character at once
* Each field to be set for each new component can be edited or erased
![Create GameObject](https://i.imgur.com/LdyvsBd.png)
* **NOTICE**: Spawning will not work well for complicated GameObjects with many components; use via.Prefabs for those. However you can spawn simple objects such as Model-Viewer figures that can be animated  

</details>

### Material Manager  
* Edit all Material parameters live and in-engine
* Change meshes, swaps textures, and disable materials or mesh components
* Remembers the saved settings and can automatically applies them in-game, as if a file mod were installed

<details>
<summary>Click Here for the Material Manager Guide and Screenshots</summary>

* Click "Save New Defaults" to save the current material settings to JSON. Any time a GameObject with the same name is found in the scene, those settings will be applied.
* Swap Mesh and Material (MDF) files and change textures using drop-down lists
* Save your changes to a MDF file by injection with EMV's RE Engine Resource Editor, or with [MDF Manager](https://github.com/Silvris/MDF-Manager) by Silvris  
* Use "Change Multi" to change properties of multiple connected GameObjects at a time. This checks all materials of all a GameObject's children, siblings and parent for materials with names matching the given keywords (separated by spaces), then changes the same material property on those GameObjects if it is found.  
![Material Manager](https://i.imgur.com/KBJYUQu.png)
* Saved Materials automatically coloring enemies skin green:
![Saved Mats](https://i.imgur.com/jfvrl4L.jpg)
* Some screenshots of simple BaseColor edits in RE8:  
![Chris White](https://i.imgur.com/922lUED.jpg)
![Daniela BlackRed](https://i.imgur.com/0OfiHFm.jpg)
![Chris Funny](https://i.imgur.com/VUswlbN.jpg)
<!--![Bela WhiteRed](https://i.imgur.com/TRiCGCw.jpg)-->
![Green Heisenberg](https://i.imgur.com/x1KXXdG.jpg)
<!--![Bela Red](https://i.imgur.com/ZaQ7QEZ.jpg)-->


</details>

### Poser  
* Rotates and freezes a model's joints to pose for screenshots, using gizmos and control panels
* Saves LocalPosition, LocalRotation, Global Position and Global Rotation separately and can load or freeze them together
* Poses can be saved and loaded as files
* Features "Undo" functionality

<details>
<summary>Click Here for the Poser Guide and Screenshots</summary>

* Hold Shift and hover your mouse over some bones to freeze them, or hold alt to un-freeze them.  
* Press 'Z' to undo the last pose actions  
* Poses can be saved to JSON files, with 8 poses per file. LocalPositions will save independently alongside Positions or Rotations to the same file, named after the selected GameObject
* Save and load a facial animation as full poses by saving both their LocalPositions and LocalRotations, then loading both together with "Import All Properties" checked  
![Poser](https://i.imgur.com/CTIqhbK.jpg)

</details>

### Action Monitor  
* Controls FSM actions and behaviors (movesets, triggers and gimmicks)    
* Includes a Sequencer (WIP)

<details>
<summary>Click Here for the Action Monitor Guide and Screenshots</summary>

* Each button activates a BehaviorTree node, which makes the character perform a full move or series of moves, complete with animations, sounds, EFX and more. Some trigger mini-cutscenes or special conditions  
* Nodes can be assigned to Hotkey buttons by clicking the "?" next to their buttons and assigning a key. These hotkeys can be managed in the EMV Engine settings menu
* Nodes can trigger Actions, which are small Managed Objects that can have a significant impact
* Save your edited FSM settings to a file with the [RSZ Template](https://github.com/alphazolam/RE_RSZ)  
![Action Monitor](https://i.imgur.com/Ofye1ww.png)

</details>

### Chain Controller  
* Visualizes physics chains as wireframe and views "CustomSettings" Chain physics settings
* Appears inside Managed Object Control Panels for "via.motion.Chain" Components  

<details>
<summary>Click Here for the Chain Controller Guide and Screenshots</summary>

* Chain CustomSettings control panels let you change ChainSettings in-engine and visualize chain physics nodes
* Save your changes to a file with the [chain template](https://residentevilmodding.boards.net/thread/14726/re8-mhrise-modding-tools) for 010 Editor  
![Chain](https://i.imgur.com/AaTOI1O.png)

</details>

### Editable Lua Tables
* EMV Engine provides a system to edit Lua tables with text boxes in imgui. Table entries can be added or removed by key+value
* String inputs will be interpreted as global variables, primitives and constants either automatically or if you input a semicolon at the end. 
* Encase a string in quotes to override the this conversion when it happens automatically
	
<details>
<summary>Click Here for the Editable Tables Guide and Screenshots</summary>

* Below is a screenshot of the standard "GameObject" Lua class used by EMV Engine, with Editable Tables disabled:  
![Editable Tables Disabled](https://i.imgur.com/LVy3pbr.png)  
* Here is the same table with Editable Tables enabled:  
![Editable Tables Enabled](https://i.imgur.com/XxPvBGq.png)  
* Input whole Lua expressions to the text box and make them be evaluated by ending with a semicolon
* Click the "Add" button to add a new Key + Value pair to a table
* Remove table entries or cancel a new addition by setting values as "nil" or "" (nothing)
* Arrays (ordered tables) are auto-detected and have special behaviors. Adding a new value and setting its key to the middle of the list will insert the new entry to that position and push all the others forward. Making an item in the middle of an array nil will trigger table.remove
* Set the new \[Key\] on the new table entry to an existing key to replace the entry (or erase it if set to nil). This is also the way to remove Tree Node elements (such as other tables and Managed Objects)  

[![Editable Tables Video](https://i.imgur.com/vMDpQqN.png)](https://cdn.discordapp.com/attachments/925838720534446100/997197236230426774/2022-07-14_13-34-40.mp4)

<!--[![Editable Tables Video]({https://i.imgur.com/vMDpQqN.png})]({https://cdn.discordapp.com/attachments/925838720534446100/997197236230426774/2022-07-14_13-34-40.mp4} "Editable Tables Video")-->

</details>

#### *You must install EMV Engine first to use any of my other scripts, which require "EMV Engine\init.lua" to be available!
  
## Lua Scripts based on EMV Engine
5 scripts have been made so far as extensions of EMV Engine: **Enhanced Model Viewer**, **Gravity Gun**, **Console**, **Enemy Spawner** and **RE Engine Resource Editor**
Below is a manual of sorts describing how to use each script and its features

# Enhanced Model Viewer
Enhanced Model Viewer ("EMV") is a powerful animation and cutscene viewer that allows you to control animations and sequences in real time.  
It will appear automatically inside the model viewers of RE2R, RE3R, DMC5 and RE8, as well as in the cutscenes of RE2R, RE3R and DMC5.  
Additionally, you can force the animation viewer to appear on most animatable objects by clicking "Enable Animation Viewer" button when viewing their object in the Managed Object Control Panels created by EMV Engine.
#### Features:
* Loads a specific selection of MotionBank resources for each game, allowing loading of most animations on any character
* Matches motbanks to characters by name and other factors, and allows you to match your own banks by clicking the "+" button next to the MotBank combobox
* Full animation for each GameObject, including the standard Play/Pause/Seek/Repeat/Shuffle as well as timescale and A-B looping
* Includes hotkeys for play, pause, centering objects and more. Hold Alt and press Step while paused to skip frame-by-frame
* Seek through RE2R, RE3R and DMC5 cutscenes and control their timescale in cutscenes with audio
* Includes modified SCN files for RE8 and DMC5 that unlock camera controls in the model viewer and add animatable gameplay models in RE8. These files will be ignored in other games
* Change the background to a greenscreen or load a specific CubeMap texture backdrop

![Chris](https://i.imgur.com/PXhHpWC.jpg)

<details>
<summary>Click Here for the Enhanced Model Viewer Controls, Features and Guide</summary>

#### Enhanced Model Viewer Settings
* **Persistent Settings** makes the script load data from JSON files. **Reset Settings** restores default settings from the script
* **Restart EMV** clears the current instance of EMV and allows it to restart naturally
* **Sync Animations** makes the game try to synchronise body, head and item animations that are part of the same GameObject, searching for matched motbanks by shared frame count
* **Transparent Background** makes the background of the Enhanced Model Viewer window become clear
* **Cutscene Viewer** Makes the cutscene viewer automatically appear in RE2R, RE3R and DMC5
* **Detach Animation/Cutscene Seek Bar** makes the animation controls and seek bar for animated non-cutscene or animated cutscene objects (respectively) become their own floating windows
* **Remove Mismatched Motlists** is a feature for when a matched motbank contains extra motlists that are of the wrong body type (facial animations for a body or vice versa), and removes mismatched ones
* **Cache Figure Data** makes Enhanced Model Viewer use saved JSON data for its matched banks and motbanks, loading them faster
* **Enable Hotkeys** makes the viewer's hotkeys (pictured below) be usable
* **Re-cache Animations** makes EMV re-read all motbank files and cache their contents. This particularly important for RE Engine games before RE8, and is what builds the huge list of motbanks, motlists and motions that EMV uses
* **Clear Motbank Resource Cache** Clears the global list of motionbanks loaded by EMV, if it has become polluted with a broken file or has not been correctly filled with data
* **Clear Figure Data** Deletes all the current Cached Figure Data described above  
![Enhanced Model Viewer Settings](https://i.imgur.com/ipuAxja.png)

#### Animation Controls
* **Selected** - EMV uses a "selection" system where one object will be the selected as the dominant object, with other objects syncing to it and changing with it. Check the **checkbox** next to an object one time to select it, or again while it is selected to **enable** or **disable** it
* **Seek Bar** - Select the current frame of the animation here. Ctrl+Click to set it to a specific frame. Press **2** or **4** with hotkeys on to seek back and forth, holding alt to do it slower (down to frame-by-frame when paused) or shift to do it faster
* **Playback Speed** - Set the playspeed of the animation. Can be put in reverse. Press **T** with hotkeys enabled to pause / unpause the selected animated object
* **Play / Pause / Reverse** are self-explanatory control-action buttons
* The **0.05x, 0.25xm 0.5x, 0.75x, 1.0x and +0.25x** buttons are used to quickly control play speed
* The **Seek All** checkbox (toggleable with the **6** key) changes whether your control inputs affect only one object or all objects associated with that object tool
* The **Prev / Next** buttons cycle through mots (animations), motlists and motbanks in the order of their lists
* The **Shuffle** button (hotkey **U**) jumps to a random animation in the list of all animations matched to the character
* The **Restart** button resets the animation from the beginning
* The **Reset Physics** button restarts Chain and Gpucloth physics components on any animated GameObjects, fixing clipping or broken jigglebones
* The **Set A-B Loop** button (hotkey **5**) lets you mark a start and an end point where the animation will loop back and forth, even between multiple mots, motlists and banks. The animation will not center itself until each time the loop completes, allowing for continuous movement around a scene
* The **Repeat** button checkbox makes it so no animation will go to the next one unless you click "Next" yourself
* The **Center** checkbox has three settings: Off, On and Aggressive. When turned on, it will try to align the object with the center of the figure by an offset, then it will re-center the object to that position after each animation completes.
* **Aggressively Forced Centering** is when the **\*Center** checkbox has a **\*** next to it, and forces the object to be always exactly on the center position
* The **Mirror** checkbox is an option for flipping an animation from left to right
* The **Sync** checkbox allows you to decide which objects you want to be subjkect to the **Sync Animations** setting described above
* The **Grab** button (toggleable with **G**) is available when the Gravity Gun is running, and lets you pick up the GameObject with the gravity gun  
![Animation Controls](https://i.imgur.com/KEcRQU9.png)

#### Bank List Controls
* Features an embedded **Controls** tree node containing a version of the controls described above for each animatable object, where you can control it specifically
* The **Select MotionBank, MotionList or Mot** combo boxes sample from motionbanks that the game uses to categorize lists (motlists) of animations (mots) for different characters, enemies and items, and allow you to pick which ones to load
* Press the **+** button next to the "Bank" combobox to add a motbank to your object's list of matched banks. This will make it work with Shuffle and Next/Prev, instead of being skipped
* Press the **Refresh** button to re-create the GameObject Lua class that is this object, reconstructing it and its banks lists if they are empty
![Animation Controls](https://i.imgur.com/s6GVTdf.png)

#### Lights menu
* The **Unlock All Lights** checkbox makes the figure scene's lights become attached to the figure instead of static in the scene, or vice versa depending on the game
* The **Rotate All** checkbox is one of my favorite features and lets the light sets circle around the figure while the figure is held still
* The **Show Positions** checkbox shows you with world-text the location of each light in the figure
* The **Follow Figure** checkbox makes the lights of the figure follow the currently selected object, so they dont move into darkness
* While the Animation Viewer has been enabled outside of gameplay, Lights are collected from nearby instead of the figure. Press the **Resample** button to recollect these lights if you have moved since they were first collected
* Each light is either unsorted or comes in a **LightSet** container, which can be enabled or disabled to turn them all on/off at once
* Check the **Unlock** checkbox to unlock only this light (as in "Unlock All Lights")
* Press the **Move to Cam** button to move the light to the position of the camera. May require "Unlock" to be enabled on the light
* If an IBL is seen in the Lights menu, its background can be set there in any game:
![Animation Controls](https://i.imgur.com/CLLiCqf.png)

#### Background
* Available for RE2R and RE3R, may come back to DMC5 soon
* Manupulates a via.render.IBL object, and can quickly load a Greenscreen background or any other background texture  
![IBL](https://i.imgur.com/X3LyjhM.png)

#### Other Objects
* **Other objects** is a dumping ground for all other unsorted objects in the figure. Objects are only shown if they are not parented to any other Other-Objects

#### Camera and Figure Behavior
* A shortcut to the current MainCamera, and some figure controls for the current figure in RE2R and RE3R. EMV automatically adjusts zoom features to allow for extreme close-ups and far distances with unlocked rotation

#### Cutscene Viewer Settings
* In RE2R, RE3R and DMC5, a special Cutscene viewer will appear to manipulate cutscenes
![CS](https://i.imgur.com/Lz9Nqv3.jpg)
* Use the Seek Bar and PlaySpeed to set the current frame of the cutscene and the current speed of the cutscene, respectively. Audio timescale cannot be changed, so it is disabled when the timescale is not 1.0
* Press the **Play/Pause** button to start and stop the cutscene, including audio
* Use the **Restart** button to restart the cutscene from the beginning, hopefully restarting all the audio as well. This button will fix issues where the cutscene viewer is not controlling the cutscene
* The **Stop Audio** button stops the cutscene audio from playing, for whenever it may become loud or broken
* The **Alt Sound Seek** checkbox changes the way in which audio is seeked in the cutscene viewer, because some games will go mute with one method and others with the other, sometimes for different scenes
* **NOTICE:** Certain cutscenes may have an issue where only the first 65535 milliseconds of playback will play audio, the rest will be muted because it just restarts beyond that point
* The **Free Cam** checkbox detaches the camera from the cutscene's control, teleporting it to 0,0,0 if you are not using the REFramework FreeCam mod. This option disables many annoying visual effects such as Depth of Fields
* The **Zoom Control** button allows you to set the current cutscene FOV / zoom-level by using the **+** and **-** keys on the num pad
* **Detach** detaches the cutscene seek bar from the Enhanced Model Viewer window, into its own window
* The **End Scene** button ends / skips the current cutscene
![CS Settings](https://i.imgur.com/93Ntv9U.png)

</details>

# Gravity Gun
The Gravity Gun allows you to manipulate 3D objects using the camera and the mouse, picking them up and moving them around. Thanks to praydog for creating the initial version. 
Certain objects are dynamic and capable of going ragdoll, such as zombies.
#### Gravity Gun Controls
* **Hold middle mouse button** to fire a ray that detects the closest collidable object to the center of the camera, and grabs it when you let go
* **Roll the mouse in** and out to reel the object in or push it away, and press middle mouse again to let go
* Hold **ALT** while rotating the camera to rotate the object in your grasp
* Hold **F** and roll the mouse wheel to change the grabbed object's scale
* Press **Z** to reset an object to its original position
* (RE2R/RE3R only) Press **G** while near a ledge to vault up it (uses the gravity gun to sense when a wall is blocking the way)

![GravGunTitle](https://i.imgur.com/eVwSLtK.jpg)
<details>
<summary>Click Here for the Gravity Gun Controls, Features & Guide</summary>

* The gravity Gun being used to carry the player (Hotkeys displayed):  
![GravityGun](https://i.imgur.com/8e3PAV5.png)
* **Forced Functions** are specific fields and properties that are set on components of a GameObject while the gravity gun holds it, or right when it picks it up / drops it:  
![Forced Functions](https://i.imgur.com/ilISn7H.png)
* The **Ray Layers Table** and **Wanted mask bits** let you configure which types of objects the gravity gun can and can't see:  
![Ray Layers Table](https://i.imgur.com/5tn12t9.png)
* **Persistent Settings** is the same shared setting used by all my scripts to load data from JSON files
* **GrabObject Action Monitor** makes the action monitor appear in a floating window for the current grabbed object, if it has BehaviorTrees
* **Show Transform** toggles whether the position, rotation and scale of the grabbed object is displayed as text below it
* **Reset All Objects** puts all objects back into their original positions (last remembered by the script)
* **Save / Load Positions** saves and loads positions, rotations and scales of all current objects handled by the script with a specific component  
![GravityGun Settings](https://i.imgur.com/Uloz0wh.png)

</details>

# Console
An interactive Lua Console / REPL, for use in researching the game engine and testing Lua code.  
It has access to a variety of useful functions from EMV Engine as well as all global variables across all running scripts.  
This makes the console useful for debugging scripts, since you can just make your variables global to check their values in the console.  
For more information on making REFramework scripts, visit the [wiki](https://cursey.github.io/reframework-book/index.html)
* Press **tab** or the **blank button** after the "Enter" button to **AutoComplete**, like in a terminal or command prompt
* Press the **UP** and **DOWN** arrow keys on your keyboard to cycle through your history of past commands
* Type '**/**' followed by some text to search the game world for objects with that text in their names
* Type '**folders**' to get a list of all via.Folders in the game. Folders (representing SCN files) are the principal way in which the game contains and loads GameObjects, and can be activated or deactivated to spawn their contents
* Type '**transforms**' to get a list of all objects in the game world, ordered by creation
* Execute multiple lines of code within the console by using semicolons to separate statements
* Use '=' to make assignments within for loops inside your Console commands, or ' = ' to make a one-line assignment and view the result  
*Example of a multi-command input, finding Timeline components with **findc** and sorting them by "amt" using the **qsort** function:*  
![MultiCommand](https://i.imgur.com/VwZ7IwM.png)

<details>
<summary>Click Here for the Console's Controls, Commands, Features & Guide</summary>

#### AutoComplete 
* **AutoComplete** is a useful tool capable of guessing what you might want to type and completing your input. Press Tab or the Blank button shown below to AutoComplete  
![AutoComplete](https://i.imgur.com/Ki8fANG.png)
* AutoComplete can give you the names of available functions, subtables, and values in the global scope as well as in your own tables and userdatas, with hidden metatable variables shown
* AutoComplete will work while typing paramaters for multiple nested function calls, as long as its at the end
* Managed Objects will autocomplete to show their RE Engine methods, using a table for their arguments like this:   
![AutoComplete Method Call](https://i.imgur.com/nV79MMc.png)
#### Console Settings  
* **Spawn Console** Makes the console window appear when it has been closed
* **Use Child Window** makes there be an text input box at the top and bottom of a large child window framed in the Console window (for quick access to input without lots of scrolling)
* **Transparent Background** makes the Console window become transparent, except for its contents
* **Always Update Lists** makes it so lists displayed in imgui are updated constantly, instead of having to click the **Update** button. This may cause flickering and slower performance  
* **Editable Tables** are described above  
![Console Settings](https://i.imgur.com/TEyty9Q.png)
#### History
* The History shows you a list of your recent commands, each as an imgui tree node
* Press the **Run Again** (can be set to a bindable Hotkey for each command) button to repeat the command one time, or check the **Keep Running** checkbox to keep it running indefinitely. "Keep Running" can display imgui functions as commands in the Console window
* When using the shortcut commands described above, you can sort lists of components by distance to the camera with the **Sort By Distance** button. Press the button again to refresh the sort
* Check the **Show Closest** button to display the closest objects in the list of results to the camera as yellow world text in the scene, giving you an idea of where things are
* Use the **Max Distance** slider to search only for the closest objects within a certain radius of the camera  
![Show Closest](https://i.imgur.com/yj236zy.jpg)

</details>

# Enemy Spawner
This script for RE2R, RE3R and DMC5 (with other spawning features for the other games) allows you to spawn any enemies at the last location that the Gravity gun was aimed at  
* In all games, PFB files (prefabs) can also be spawned, creating a new instance of the GameObject contained in the PFB, from enemies to EFX effects
* Includes custom SCN files that add new via.Folders to the game, to contain the spawned enemies and manage them separately

![EnemySpawner](https://i.imgur.com/sqIqPWk.jpg)

<details>
<summary>Click Here for Enemy Spawner Guide and Screenshots</summary>

#### Enemy Spawner Controls / Settings
* Select and Enemy to spawn from the drop down list in the supported games. All enemies and bosses should be spawnable as many times as you like
* **Spawn Random Zombie** will spawn a random zombie in RE2R or RE3R. **Spawn Random Enemy** will spawn any enemy, and could spawn a boss
* The **Loiter** checkbox makes it so zombies and other enemies will wanter around periodically instead of just standing there  

![EnemySpawnerControls](https://i.imgur.com/dT9OyTl.png)

#### Prefab Spawner
* You can use the **Prefabs** component of the Enemy Spawner to spawn PFB files you get from anywhere in any of the games (not just the three). PFB files will be cached as they are seen. 
* The **Add PFB File** text input allows you to specially add a PFB file to the spawner's list. You can try searching through the PFB files listed in the [file list](https://residentevilmodding.boards.net/thread/10567/pak-tex-editing-tool) for each game to find the filepaths of PFB files to spawn
* The **Clear Spawns** button will wipe away all spawned enemies like they never existed. **NOTE:** This button also clears Spawned GameObjects from the Collection
* The **Existing Spawns** imgui tree node contains a list of all current spawned enemies, where they can be configured with Managed Object Control Panel and made to loiter individually

</details>

# RE Engine Resource Editor
RE Engine Resource Editor is a powerful script that can save and load PFB, SCN, and USER files for RE8 and all games after, and MDF2 files from all games.
* Use the same JSON dumps as used in the [RSZ Template](https://github.com/alphazolam/RE_RSZ) to read and write important game files
* Add components, instances, change Parents and recreate whole files entirely from Lua tables
* Save Material edits from EMV directly to the corresponding MDF file

![REEngineResourceEditor](https://i.imgur.com/MARlxvW.jpg)

<details>
<summary>Click Here for RE Engine Resource Editor Guide and Screenshots</summary>

#### File Loader
* Copy and paste the filepath of a MDF2, SCN, PFB, or USER file into the text box to read the file
* Files can be loaded from the "reframework\data" folder, or from your game's natives folder using the syntax "$natives\myFile.pfb.17"
* Opened files will be displayed in the "Opened Files" tree
* Click the "X" button to close a file

![FileLoader](https://i.imgur.com/5JwHNei.png)

#### RSZ Resources (PFB, SCN, USER)
* RSZ resources require special JSON dumps to be read correctly. These dumps can be found at the [RSZ Template](https://github.com/alphazolam/RE_RSZ) repository, and must be placed in the `reframework\data\
* Reading RSZ Resources from DMC5 and original RE2 and RE7 is not currently supported due to user.2 files being embedded
* Features include changing all RSZ fields, swapping ObjectIDs (references), GameObject parents, inserting Instances, inserting Components, adding / removing all non-RSZ structs, and more
* Save SCN files as PFB files and PFB files as SCN files
* More guides soon, download this video for a demonstration:

[![RSZFileEditDemo](https://i.imgur.com/Yrr3pXq.png)](https://cdn.discordapp.com/attachments/925838720534446100/1001933610594599073/2022-07-27_15-20-28.mp4)

#### MDF Files
* Each component of the MDF File is displayed with features to add and remove structs
* Edit colors and other parameters in the ParamHeaders themselves, or change texture strings. Any aspect of the file can be edited.
* Click "Save File" from the Materials menu to inject and existing MDF file with your current mesh material settings

![MDFReader](https://i.imgur.com/tUQQZgq.png)

</details>

# Troubleshooting / Bugs
* If your game is crashing on startup or when loading certain areas or animations, delete all JSON files in the reframework/data folder related to EMV Engine and Enhanced Model Viewer, as over time they may get corrupted by trying to cache unloadable files.
* Try playing around with the Garbage Collection settings on newer versions of REFramework if you are getting constant crashes in some games. Generational may be faster than Incremental, but is more unstable
* It is recommended that you install all five scripts together to avoid errors, as I usually develop them together

# Scripters
Feel free to make your own extensions to EMV Engine by requiring it at the top of your script, and use the multitude of available utility functions to support your own scripts. Most available functions are described with comments inside *EMV Engine\init.lua*, and all of EMV's exported functions and tables are available in a global table called **EMV** while EMV Engine is running  
Just be sure to give credit where it is due, and to link users to this repo for the newest updates to EMV Engine.

![Bela](https://i.imgur.com/Zd6QBax.jpg)

#### Huge thanks to praydog for making REFramework and for all the guidance
*\*These scripts are each a work-in-progress and may have bugs or cause crashes across the various game and engine versions*  

							
					Created by alphaZomega, 2022