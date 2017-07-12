# wipeout-autopilot
A lua script for PSXjin emulator that autopilot player ship in Wipeout 2097 PSX game.

### How to use it :

1. Download PSXjin emulator revision 726 or higher (search for "PSXjin r726")
2. Start the game and launch a race. "Feisar" ship has to be selected (see limitations below)
3. In the emulator: 
   - Go to "File" > "Lua Scripting" > "New Lua Script Window..."
   - Click on "Browse..."
   - Select "wipeout.lua" script
   - Click on "Run"
4. Accelerate the ship using X button and enjoy autopilot.

Note : the script has be to executed when in the race, not before (eg : in the menus).
If you change the track, you have to stop and re-run the script each time. 

### Known bugs / limitations :

- It only steers the ship left or right. 
- It does not :
  - accelerate/brake (you have to do it yourself)
  - use air brakes 
  - use weapons
  - adjust ship pitch (using up down buttons)
  - avoid other AI ships
- Because of some limitations (eg: no air brakes), it cannot handle sharp turns at high speed.
- At low speeds (eg : < 50 mph) it might anticipate turns too early and hit the track.
- It only works with Feisar team. The script need to know the position of the ship, and the memory address is different for each team.
- It has only been tested with Wipeout 2097 PAL version. I don't know if it works with other game versions.

### How it works :

The track can be described by a huge 3d curve, made of 3d points equally spaced.
This information exists in the original game and is used for AI ships (so they know how to drive) and for the autopilot item.
The script use that information and check what is nearest 3D point to the ship position. Then, it calculates the angle difference between the ship direction and that point.
Depending the angle difference, it steer the ship left or right. The whole thing is stabilized using a [PID controller](https://en.wikipedia.org/wiki/PID_controller). 

### Possible improvements :

- Implement air brakes / acceleration.
- Avoid other ships.
- Use a better racing line. For the moment, it consider a line which at the middle of the track. This is definitely not the best possible curve.
- Take care of ship speed or other inputs to handle turns in a better way. 
- Use analog input (neGcon controller) for steering the ship. Actally, the ship is controlled using left right buttons and pulse with modulation, which is not precise.