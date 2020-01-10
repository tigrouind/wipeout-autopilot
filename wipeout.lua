local function findTrackMemoryAddress()
	--look in PSX ram for a track section pattern
	local sectionsAddr = 0x00000000
	for readposition = 0x00100000, 0x001fffff, 4 do
		if (memory.read_u32_le(readposition) == 0xffffffff 
		and memory.read_u16_le(readposition + 24) == 8
		and memory.read_s16_le(readposition + 146) == 0x7FFF
		and memory.read_s16_le(readposition + 148) == 0x7FFF) then
			--found!
			sectionsAddr = readposition
			break
		end
	end
	
	return sectionsAddr
end

local function getTrackSections()
	--read all track sections and store them in array
	local sectionsAddr = findTrackMemoryAddress()
	local readposition = sectionsAddr
	local track = {}
	local i = 0
	
	repeat
		local section = {}
		section.x = memory.read_s32_le(readposition + 12)
		section.y = memory.read_s32_le(readposition + 16)
		section.z = memory.read_s32_le(readposition + 20)
		section.next = (bit.band(memory.read_u32_le(readposition + 8), 0x00ffffff) - sectionsAddr) / 156 -- + 1

		track[i] = section
		
		readposition = readposition + 156
		i = i + 1
	until memory.read_u16_le(readposition + 24) ~= 8
	
	return track
end

local function convertTrack(track)
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

local function trackSize(track)
	local count = 0
	for index, point in next, track do
		count = count + 1
	end	
	return count
end

local track = convertTrack(getTrackSections())
local trackCount = trackSize(track)

--PID
local lasterror = 0
local integral = 0

while true do
	
	--lock remaining lap time to 9:59.9
	--memory.write_u16_le(0x00095814, (9*600+59*10+9)*5) 
	
	--read ship info
	local positionx = memory.read_s32_le(0x001111CC) --0x0011149C (Piranha)
	local positiony = memory.read_s32_le(0x001111D0) --0x001114A0
	local positionz = memory.read_s32_le(0x001111D4) --0x001114A4
	
	--local speedx = memory.read_s32_le(0x001111DC) / 200
	--local speedy = memory.read_s32_le(0x001111E0) / 200
	--local speedz = memory.read_s32_le(0x001111E4) / 200
	
	--local thrust = memory.read_u16_le(0x00111224)
	local speed = memory.read_u16_le(0x00111220)
	local angle = (memory.read_s16_le(0x001111FC) / 2048) * math.pi	
	
	--find nearest track section
	local smallestdist = 999999999
	local nearestindex = 1
	for index, point in next, track do
		local dx = positionx - point.x
		local dy = positiony - point.y
		local dz = positionz - point.z
	
		local distance = dx * dx + dy * dy + dz * dz
		if distance < smallestdist then
			smallestdist = distance
			nearestindex = index
		end
	end
	
	--calculate the difference between player angle and where ship should aim at (track middle section)
	local nearestpoint = track[(nearestindex + 3 + math.floor(speed / 9000))%trackCount]
	local targetangle = -math.atan2(nearestpoint.x - positionx, nearestpoint.z - positionz)

	--memory.write_s32_le(0x001110DC, nearestpoint.x) --AI ship
	--memory.write_s32_le(0x001110E0, nearestpoint.y)
	--memory.write_s32_le(0x001110E4, nearestpoint.z)
	--memory.write_s16_le(0x001111FC, targetangle / math.pi * 2048)
	
	--PID
	local diffangle = math.atan2(math.sin(angle - targetangle), math.cos(angle - targetangle))
	local error = diffangle
	
	integral = integral + error
	if (integral > 10000) then 
		integral = 10000
	elseif(integral < -10000) then
		integral = -10000
	end
	
	local derivative = error - lasterror
	lasterror = error

	kp = 0.045
	ki = 0.00004
	kd = 0.3
	gain = 0.07
	
	output = (error * kp + derivative * kd + integral * ki) * gain
	
	--debugging
	gui.text(0, 50, "X: " .. positionx)
	gui.text(0, 70, "Y: " .. positiony)
	gui.text(0, 90, "Z: " .. positionz)
	gui.text(0,110, "TRACK: " .. nearestindex)
	gui.text(0,130, "ANGLE: " .. math.floor(angle / math.pi * 180))
	gui.text(0,150, "DIFFANGLE: " .. math.floor(diffangle / math.pi * 180))
	gui.text(0,170, "SPEED: " .. math.floor(speed/95))

	--reset joypad state
	local joy = joypad.get(1)
	for key,value in pairs(joy) do
		joy[key] = ''
	end
	
	--steer ship left or right
	if (output < 0) then
		joy["Left"] = 1	 
		if (error <-0.25) then joy["L1"] = 1 end
	else
		joy["Right"] = 1	 
		if (error > 0.25) then joy["R1"] = 1 end
	end
	
	joypad.set(joy, 1)
	emu.frameadvance()
end

