
function math.sign(x)
   if x < 0 then
     return -1
   elseif x > 0 then
     return 1
   else
     return 0
   end
end

---calculates distance between a point (x, y) and a line
function point2LineDistNotAbsolute(x, y, a) 
	return x * math.sin(a) - y * math.cos(a);
end

function lineLen2Point(x, y, a) 
	return x * math.cos(a) + y * math.sin(a);
end


function getTrackSections()

	--look in PSX ram for a track section pattern
	local sectionsAddr = 0x00000000
	for readposition = 0x00000000, 0x001fffff, 4 do
		if (memory.readdwordunsigned(readposition) == 0xffffffff 
		and memory.readwordunsigned(readposition + 24) == 8
		and memory.readwordsigned(readposition + 146) == 0x7FFF
		and memory.readwordsigned(readposition + 148) == 0x7FFF) then
			--found!
			sectionsAddr = readposition
			break
		end
	end
	
	--read all track sections and store it in array
	local readposition = sectionsAddr
	local track = {}
	local i = 0
	
	repeat
		section = {}
		section.x = memory.readdwordsigned(readposition + 12)
		section.y = memory.readdwordsigned(readposition + 16)
		section.z = memory.readdwordsigned(readposition + 20)
		section.next = (bit.band(memory.readdwordunsigned(readposition + 8), 0x00ffffff) - sectionsAddr) / 156 -- + 1

		track[i] = section
		
		readposition = readposition + 156
		i = i + 1
	until memory.readwordunsigned(readposition + 24) ~= 8
	
	return track
end

function convertTrack(track)
	--convert track single linked list to a array of points (pit lanes are skipped)
	local newtrack = {}
	
	local i = 0
	local currentTrack = track[0]
	repeat
		newtrack[i] = currentTrack
		currentTrack = track[currentTrack.next]
		i = i + 1
	until track[0] == currentTrack
	
	track = newtrack
	return newtrack
end

trackcount = 0
track = convertTrack(getTrackSections())
for index, point in next, track do
	trackcount = trackcount + 1
end

--ship 
oldposx = 0
oldposy = 0
oldposz = 0

velocityx = 0
velocityy = 0
velocityz = 0

--PID
error = 0
lasterror = 0
integral = 0
derivative = 0

--framerate lock
framescript = 0
starttime = os.clock()

while true do
	
	--fix: lock framerate at 30 fps
	elapsed = os.clock() - starttime
	
	if ((elapsed - framescript / 30) > 10) then
		starttime = os.clock()
	end
	
	while elapsed < framescript / 30 do
		elapsed = os.clock() - starttime
	end
	
	--lock remaining lap time to 9:59.9
	--memory.writeword(0x00095814, (9*600+59*10+9)*5) 
	
	--read ship position
	positionx = memory.readdwordsigned(0x001111CC) --0x0011149C (Piranha)
	positiony = memory.readdwordsigned(0x001111D0) --0x001114A0
	positionz = memory.readdwordsigned(0x001111D4) --0x001114A4
	frame = emu.framecount()
	
	--find nearest track section
	readposition = tracksections
	smallestdist = 999999999
	nearestindex = 1
	for index, point in next, track do
		dx = positionx - point.x
		dy = positiony - point.y
		dz = positionz - point.z
	
		distance = dx * dx + dy * dy + dz * dz
		if distance < smallestdist then
			smallestdist = distance
			nearestindex = index
		end	
	end
	
	--calculate ship angle from velocity
	if positionx ~= oldposx or positiony ~= oldposy or positionz ~= oldposz then
		velocityx = positionx - oldposx
		velocityy = positiony - oldposy
		velocityz = positionz - oldposz
		angle = math.atan2(velocityz, velocityx)
		
		oldposx = positionx
		oldposy = positiony
		oldposz = positionz
	end 
	
	--calculate the difference between player angle and where ship should aim at (track middle section)
	speed = math.sqrt(velocityx*velocityx + velocityy*velocityy + velocityz*velocityz)
	nearestpoint = track[(nearestindex + 2 + math.floor(speed/130))%trackcount]
	
	dx = nearestpoint.x - positionx 
	dz = nearestpoint.z - positionz 
	
	l = math.sqrt(dx * dx + dz * dz)
	
	dist = point2LineDistNotAbsolute(dx/l, dz/l, angle) * 1000
	
	--reverse the distance if needed
	d1 = lineLen2Point(dx, dz, angle)
	if(d1 < 0) then
		dist = 9999999 * math.sign(dist)
	end
	
	--PID
	error = dist
	
	integral = integral + error
	if (integral > 10000) then 
		integral = 10000
	elseif(integral < -10000) then
		integral = -10000
	end
	
	derivative = error - lasterror
	lasterror = error

	kp = 0.025
	ki = 0.00004
	kd = 0.3
	gain = 1.3
	
	output = (error * kp + derivative * kd + integral * ki) * gain
	
	--debugging
	gui.text(0, 50, "X: " .. positionx)
	gui.text(0, 60, "Y: " .. positiony)
	gui.text(0, 70, "Z: " .. positionz)
	gui.text(0, 80, "TRACK: " .. nearestindex)
	gui.text(0,100, "ANGLE: " .. angle / math.pi * 180 )
	gui.text(0,110, "OUTPUT: " .. math.floor(output))
	gui.text(0,120, "SPEED: " .. speed)
	
	
	--fix: all joypad states must be initialized to nil (instead of false)
	joy = joypad.get(1)
	for key,value in pairs(joy) do
		if not joy[key] then
			joy[key] = nil
		end
	end	
	
	--steer ship left or right, using PWM
	if(output < 0) then
		output = -output
		if(frame % 8 <= output) then
			joy["left"] = 1
		end
	else
		if(frame % 8 <= output) then
			joy["right"] = 1
		end	
	end
	joypad.set(1, joy)
	
	framescript = framescript + 1
	
	emu.frameadvance()
end

