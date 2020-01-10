

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
	local currentPos = track[0]
	repeat
		newtrack[i] = currentPos
		currentPos = track[currentPos.next]
		i = i + 1
	until track[0] == currentPos
	
	return newtrack
end

trackcount = 0
track = convertTrack(getTrackSections())
for index, point in next, track do
	trackcount = trackcount + 1
end

--PID
error = 0
lasterror = 0
integral = 0
derivative = 0

while true do
	

	--lock remaining lap time to 9:59.9
	--memory.writeword(0x00095814, (9*600+59*10+9)*5) 
	
	--read ship info
	positionx = memory.readdwordsigned(0x001111CC) --0x0011149C (Piranha)
	positiony = memory.readdwordsigned(0x001111D0) --0x001114A0
	positionz = memory.readdwordsigned(0x001111D4) --0x001114A4
	
	--speedx = memory.readdwordsigned(0x001111DC) / 200
	--speedy = memory.readdwordsigned(0x001111E0) / 200
	--speedz = memory.readdwordsigned(0x001111E4) / 200
	
	--thrust = memory.readword(0x00111224)
	speed = memory.readword(0x00111220)
	angle = (memory.readwordsigned(0x001111FC) / 2048) * math.pi	
	
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
	
	--calculate the difference between player angle and where ship should aim at (track middle section)
	nearestpoint = track[(nearestindex + 3 + math.floor(speed / 6000))%trackcount]
	targetangle = -math.atan2(nearestpoint.x - positionx, nearestpoint.z - positionz);

	--memory.writedword(0x001110DC, nearestpoint.x); --AI ship
	--memory.writedword(0x001110E0, nearestpoint.y);
	--memory.writedword(0x001110E4, nearestpoint.z);
	
	--PID
	diffangle = math.atan2(math.sin(angle-targetangle), math.cos(angle-targetangle))
	error = diffangle
	
	integral = integral + error
	if (integral > 10000) then 
		integral = 10000
	elseif(integral < -10000) then
		integral = -10000
	end
	
	derivative = error - lasterror
	lasterror = error

	kp = 0.045
	ki = 0.00004
	kd = 0.3
	gain = 0.07
	
	output = (error * kp + derivative * kd + integral * ki) * gain
	
	--debugging
	gui.text(0, 50, "X: " .. positionx)
	gui.text(0, 60, "Y: " .. positiony)
	gui.text(0, 70, "Z: " .. positionz)
	gui.text(0, 80, "TRACK: " .. nearestindex)
	gui.text(0,100, "ANGLE: " .. math.floor(angle / math.pi * 180))
	gui.text(0,110, "DIFFANGLE: " .. math.floor(diffangle / math.pi * 180))
	gui.text(0,120, "SPEED: " .. math.floor(speed/95))

	--fix: all joypad states must be initialized to nil (instead of false)
	joy = joypad.get(1)
	for key,value in pairs(joy) do
		if not joy[key] then
			joy[key] = nil
		end
	end
	
	--steer ship left or right
	if(output < 0) then
		joy["left"] = 1	 
		if (error <-0.25) then joy["l1"] = 1 end
	else
		joy["right"] = 1	 
		if (error > 0.25) then joy["r1"] = 1 end
	end
	
	joypad.set(1, joy)
	
	emu.frameadvance()
end

