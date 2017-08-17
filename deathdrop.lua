local Methods = {}

local enableSafeZones = true -- If true then PVP in safezone will jail the killer and items will not drop
local dropItemsOnDeath = true -- Allow dropping of Items on death
local dropItemsFromPVP = true -- Do you want players to be able to take items from other players in PVP.
local dropItemsFromPVE = true -- Do you want players to have to run back to their gear after a lost fight with nature.
local dropItemsFromPVEInSafeZone = true -- Do you want players to drop their items in SafeZone if killed by NPC
local dropItemsFromSuicide = true -- This could mean player died from magic, or committed suicide.
local dropItemsFromSuicideInSafeZone = false -- Can be used as a way around SafeZone if enabled.
local dropItemsWhenJailed = true -- When a player spawn kills their items will drop before being sent to jail

local jailTimeInMins = 5
local jailedMsg = "You were sent to jail for killing a player in a safezone, your sentence is "..jailTimeInMins.." minutes.\n"
local releaseMsg = "You were released from jail.\n"
local jailMsgColor = color.DarkSalmon

local broadcastWhenPlayerGetsJailed = true
local msg = " was sent to jail for killing another player in a safezone.\n"
local msgColor = color.DarkSalmon

local safeExteriorCells = {"-3, -2", "-3, -1", "-3, -3", "-2, -2", "-4, -2"}
local safeInteriorCellHeaders = {"Balmora,"}
local notifyIfInSafeZone = true
local enteringMsg = "You have entered a safezone.\n"
local exitingMsg = "You have left a safezone.\n"
local enterMsgColor = color.Green
local exitMsgColor = color.Red

-- you can use [ deathDrop.IsPlayerInJail(pid) ] and [ deathDrop.IsPlayerInSafeZone(pid) ] for your custom scripts if your script needs to know if someone is in the safezone or jailed.

local jail1 = 
{
	cell = "Vivec, Hlaalu Prison Cells",
	posX = 245,
	posY = 504,
	posZ = -114.6,
	rotX = 0.11703610420227,
	rotZ = 3.1264209747314
}

local jail2 = 
{
	cell = "Vivec, Hlaalu Prison Cells",
	posX = 253,
	posY = -279,
	posZ = -116,
	rotX = 0.12100458145142,
	rotZ = 0.007171630859375
}

local jailcells = {jail1, jail2}


local jailed = {}
local safePlayers = {}

Methods.OnPlayerDeath = function(pid)

	local player = Players[pid]
	local reason = tes3mp.GetDeathReason(self.pid)
	
	local cellDescription = player.data.location.cell
	
	local diedInSafeZone = false
	local diedToAPlayer = false
	local diedToUnknown = false
	
	if Methods.IsPlayerInSafeZone(pid) == true then
		diedInSafeZone = true
	end

	local cell = LoadedCells[cellDescription] -- Get the cell that player died in
	local killer = nil
	
	if reason ~= "suicide" then -- Dont even search for killer if it is unknown
		for index,p in pairs(cell.visitors) do -- Check visitors in cell to try and find killer
			local possibleKiller = Players[p]
			if reason == possibleKiller.data.login.name then
				killer = possibleKiller
				diedToAPlayer = true
				break
			end
		end
	else
		diedToUnknown = true -- Death was "suicide"
	end
	
	local decision = false
	
	if dropItemsOnDeath == true then -- This whole block determines the decision to drop players items based on config
		if diedInSafeZone == true and enableSafeZones == true then
			if diedToAPlayer == true then -- Died to player in safezone
				if killer ~= nil then
					tes3mp.SendMessage(killer.pid, jailMsgColor..jailedMsg..color.Default, false)
					if broadcastWhenPlayerGetsJailed == true then
						tes3mp.SendMessage(killer.pid, "[SERVER] :"..msgColor..killer.data.login.name..msg..color.Default, true)
					end
					addJailed(killer.pid)
					tes3mp.SetHealthCurrent(killer.pid, 0) -- Kill the Killer then send him to jail
					tes3mp.SendStatsDynamic(killer.pid)
					killer.tid_jailed = tes3mp.CreateTimerEx("UnJailPlayer", time.seconds(jailTimeInMins*60), "i", killer.pid)
					tes3mp.StartTimer(killer.tid_jailed)
				end
			elseif diedToUnknown == true then -- Died to Suicide/Magic in safezone
				if dropItemsFromSuicideInSafeZone == true then
					decision = true
				end
			else 							-- Died to NPC in safezone
				if dropItemsFromPVEInSafeZone == true then
					decision = true
				end
			end
		else
			if diedToAPlayer == true then -- Died to player in wild
				if dropItemsFromPVP == true then
					decision = true
				end
			elseif diedToUnknown == true then -- Died to Suicide/Magic in wild
				if dropItemsFromSuicide == true then
					decision = true
				end
			else 							-- Died to NPC in wild
				if dropItemsFromPVE == true then
					decision = true
				end
			end
		end
	end

	if setContains(jailed, pid) == true and dropItemsWhenJailed == true then -- If you are jailed you lose items
		decision = true
	end
	
	if decision == true then
		
		local x = tes3mp.GetPosX(pid) -- gets player position.
		local y = tes3mp.GetPosY(pid) + 1
		local z = tes3mp.GetPosZ(pid)
		
		for index,item in pairs(player.data.equipment) do
			tes3mp.UnequipItem(pid, index) -- creates unequipItem packet
			tes3mp.SendEquipment(pid) -- sends packet to pid
		end
		
		local temp = player.data.inventory
		
		player.data.inventory = {} -- clear inventory data in the files
		player.data.equipment = {}
		
		tes3mp.ClearInventory(pid) -- clear inventory data on the server
		tes3mp.SendInventoryChanges(pid)

		local currentMpNum = WorldInstance:GetCurrentMpNum() + 1 -- Store the MpNum for the first object in the inventory
		local tempMpNum
		
		for _,p in pairs(Players) do -- Send the packet to each player online
			local playerID = p.pid
			tempMpNum = currentMpNum -- this will be the "iterator" each packet needs to send the same MpNum for each item or duplicates happen
			for index,item in pairs(temp) do -- Construct and send the packet
				local mpNum = tempMpNum + 1 -- The current MpNum is being used so increment by 1
				tes3mp.InitiateEvent(playerID) -- Creates packet for "pid" to be sent
				tes3mp.SetEventCell(cellDescription) -- Let packet know what cell we are talking about
				tes3mp.SetObjectRefId(item.refId)
				tes3mp.SetObjectCount(item.count)
				tes3mp.SetObjectCharge(item.charge) -- Add object data to packet
				tes3mp.SetObjectPosition(x, y, z)
				tes3mp.SetObjectRefNumIndex(0)
				tes3mp.SetObjectMpNum(mpNum)
				tes3mp.AddWorldObject() -- Actually binds the object to packet
				tes3mp.SendObjectPlace() -- sends created packet to initiated pid in InitiateEvent(pid)
				tempMpNum = tempMpNum + 1 -- go to the next available MpNum
			end
		end
		WorldInstance:SetCurrentMpNum(tempMpNum) -- set new MpNum so other server functions dont try to overwrite our new world objects
	end
end

Methods.OnPlayerCellChange = function(pid)
	if setContains(jailed, pid) == true then -- Check to see if player is jailed
		local jail = jailcells[jailed[pid]] -- Get the cell player is supposed to be in
		if Players[pid]:IsLoggedIn() then
			if Players[pid].data.location.cell ~= jail.cell then -- If player left the cell they will be teleported back
				tes3mp.SetCell(pid, jail.cell)
				tes3mp.SendCell(pid)
				tes3mp.SetPos(pid, jail.posX, jail.posY, jail.posZ)
				tes3mp.SetRot(pid, jail.rotX, jail.rotZ)
				tes3mp.SendPos(pid)
			end
		end
	elseif setContains(safePlayers, pid) and notifyIfInSafeZone == true then -- If player is not jailed and supposed to be in safezone
		if Methods.IsPlayerInSafeZone(pid) == false then -- If player is no longer in safezone send notification
			tes3mp.SendMessage(pid, exitMsgColor..exitingMsg, false)
			removeFromSet(safePlayers, pid)
		end
	elseif Methods.IsPlayerInSafeZone(pid) and notifyIfInSafeZone == true then -- If player is not jailed and was not previously in a safezone send notification
		tes3mp.SendMessage(pid, enterMsgColor..enteringMsg, false)
		addToSet(safePlayers, pid)
	end
end

Methods.OnObjectSpawn = function(pid, cellDescription) -- Disable assassins in safezones and jail cells

	if enableSafeZones == true then
		tes3mp.ReadLastEvent() -- Server doesnt save objects to memory so we only get access to the current packet sent which was "OnObjectSpawn"
		
		local inSafeZone = false
		local isObjectAssassin = false
		local Assassins = {}
		local found = 0
		
		for i = 0, tes3mp.GetObjectChangesSize() - 1 do -- Loop through all objects sent in packet
			local refId = tes3mp.GetObjectRefId(i)
			print("I FOUND A: "..refId)
			if refId:match("db_assassin") ~= nil then
				isObjectAssassin = true
				Assassins[found] = tes3mp.GetObjectMpNum(i) -- This is how we get the MP num for actors
				found = found + 1
			end
		end
		
		if found > 0 then
			if Methods.IsPlayerInJail(pid) == false then -- If player is jailed automatically disallow assassin spawns
				inSafeZone = Methods.IsPlayerInSafeZone(pid)
			else
				inSafeZone = true
			end
			
			if inSafeZone == true then
				for i,p in pairs(Players) do -- Do this for each player online
					for index,a in pairs(Assassins) do -- Sometimes more than one assassin spawns
						tes3mp.InitializeEvent(p.pid)
						tes3mp.SetEventCell(cellDescription)
						tes3mp.SetObjectRefNumIndex(0)
						tes3mp.SetObjectMpNum(a) 
						tes3mp.AddWorldObject() -- Add actor to packet
						tes3mp.SendObjectDelete() -- Send Delete
						
						if LoadedCells[cellDescription] ~= nil then
                    					local refIndex = "0-" .. a
                   					LoadedCells[cellDescription].data.objectData[refIndex] = nil
                    					tableHelper.removeValue(LoadedCells[cellDescription].data.packets.spawn, refIndex)
                    					tableHelper.removeValue(LoadedCells[cellDescription].data.packets.actorList, refIndex)
                    					LoadedCells[cellDescription]:Save()
                				end
					end
				end
			end
		end
	end
end

Methods.IsPlayerInJail = function(pid)
	return setContains(jailed, pid)
end

Methods.IsPlayerInSafeZone = function(pid)
		
		local inSafeZone = false
		local cellDescription = Players[pid].data.location.cell

		for index,c in pairs(safeExteriorCells) do -- Check if cellDescription is an exterior safezone
			if (c == cellDescription) then
				inSafeZone = true
				break
			end
		end

		for index,header in pairs(safeInteriorCellHeaders) do
			if cellDescription:match(header) ~= nil then -- All interiors with the prefix matching a header will also be a safezone
				inSafeZone = true
				break
			end
		end
		
		return inSafeZone
end

function UnJailPlayer(pid) -- this is called by the timer
	tes3mp.SendMessage(pid, jailMsgColor..releaseMsg..color.Default, false)
	if config.defaultRespawnCell ~= nil then
        tes3mp.SetCell(pid, config.defaultRespawnCell)
        tes3mp.SendCell(pid)

        if config.defaultRespawnPos ~= nil and config.defaultRespawnRot ~= nil then
            tes3mp.SetPos(pid, config.defaultRespawnPos[1], config.defaultRespawnPos[2], config.defaultRespawnPos[3])
            tes3mp.SetRot(pid, config.defaultRespawnRot[1], config.defaultRespawnRot[2])
            tes3mp.SendPos(pid)
        end
    end
	removeFromSet(jailed, pid)
end

function addJailed(key)
	local room = math.random(table.getn(jailcells) + 1)
	print(table.getn(jailcells).." _ "..room)
	jailed[key] = room
end

function addToSet(set, key)
	set[key] = true
end

function removeFromSet(set, key)
    set[key] = nil
end

function setContains(set, key)
    return set[key] ~= nil
end

return Methods
