-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v13
-- (GUI Whitelist & Persistent Memory Edition)
-- ==========================================

local scanner = peripheral.find("player_detector")
local reader = peripheral.find("block_reader")

local yawPosRelay   = peripheral.wrap("redstone_relay_0") 
local yawNegRelay   = peripheral.wrap("redstone_relay_1") 
local pitchPosRelay = peripheral.wrap("redstone_relay_2") 
local pitchNegRelay = peripheral.wrap("redstone_relay_3") 
local fireRelay     = peripheral.wrap("redstone_relay_4") 

if not scanner or not reader then
    print("ERROR: Sensors offline. Check modems (Player Detector required).")
    return
end

-- ==========================================
-- 1. CALIBRATION ZONE 
-- ==========================================
local maxRange = 100 -- HARD LIMIT: Will not track anyone beyond 100 blocks
local yawOffset = -140 
local invertPitch = false 
local deadzone = 10.0  

-- EXACT Cannon Mount World Coordinates:
local mountX = 2546
local mountY = -60
local mountZ = 1324

-- ==========================================
-- 2. PERSISTENT WHITELIST MEMORY
-- ==========================================
local whitelist = {}

local function loadWhitelist()
    if fs.exists("whitelist.txt") then
        local file = fs.open("whitelist.txt", "r")
        local data = file.readAll()
        file.close()
        whitelist = textutils.unserialize(data) or {}
    end
end

local function saveWhitelist()
    local file = fs.open("whitelist.txt", "w")
    file.write(textutils.serialize(whitelist))
    file.close()
end

loadWhitelist() -- Load memory on boot

-- ==========================================

local logicTickRate = 0.05  
local uiTickRate = 1.0      

local allOnlinePlayers = {}
local cachedTargets = {}
local scanError = nil
local sysStatus = "STANDBY"
local uiMode = "HUD" -- Can be "HUD" or "WHITELIST"

local function wrapAngle(angle)
    return (angle + 180) % 360 - 180
end

local function setRelay(relay, state)
    if relay then 
        pcall(function()
            relay.setOutput("top", state); relay.setOutput("bottom", state)
            relay.setOutput("left", state); relay.setOutput("right", state)
            relay.setOutput("front", state); relay.setOutput("back", state)
        end)
    end
end

-- ==========================================
-- UI DRAWING LOGIC
-- ==========================================
local function drawUI(gunY, gunP, tarY, tarP)
    term.clear()
    term.setCursorPos(1, 1)
    
    if uiMode == "HUD" then
        print("=== CIWS OVERWATCH HUD v13 ===")
        if scanError then print("RADAR: " .. tostring(scanError)) else print("RADAR: ACTIVE | SYS: " .. sysStatus) end
        
        print(string.format("GUN IS AT -> Yaw: %.1f | Pitch: %.1f", gunY or 0, gunP or 0))
        if tarY then
            print(string.format("MATH WANTS-> Yaw: %.1f | Pitch: %.1f", tarY, tarP))
        else
            print("MATH WANTS-> NO TARGET")
        end
        print("----------------------------------------")
        
        for i = 1, 10 do
            term.setCursorPos(1, 6 + i)
            local p = cachedTargets[i]
            if p then
                local prefix = "[ ]"
                if i == 1 then prefix = "[X]" end 
                print(string.format("%d. %s %s (%dm)", i, prefix, p.name, p.distance))
            end
        end

        term.setCursorPos(1, 18)
        print("[ MANAGE WHITELIST ]")
        
    elseif uiMode == "WHITELIST" then
        print("=== SECURITY WHITELIST MANAGER ===")
        print("Click a player to toggle security clearance.")
        print("----------------------------------------")
        
        for i = 1, 12 do
            term.setCursorPos(1, 3 + i)
            local pName = allOnlinePlayers[i]
            if pName then
                local status = "[ TARGET ]"
                if whitelist[pName] then status = "[  SAFE  ]" end
                print(string.format("%d. %s %s", i, status, pName))
            end
        end

        term.setCursorPos(1, 18)
        print("[ BACK TO COMBAT HUD ]")
    end
end

-- ==========================================
-- LOOP 1: RADAR (Global Player Search)
-- ==========================================
local function radarLoop()
    while true do
        local success, players = pcall(scanner.getOnlinePlayers)
        local newTargets = {}

        if success and type(players) == "table" then
            scanError = nil
            allOnlinePlayers = players
            
            for _, pName in ipairs(players) do
                -- Only calculate firing solutions for people NOT on the whitelist
                if not whitelist[pName] then
                    local sPos, pPos = pcall(scanner.getPlayerPos, pName)
                    
                    if sPos and pPos and type(pPos) == "table" then
                        -- The 100-Block Range Enforcer
                        local dist = math.floor(math.sqrt((pPos.x - mountX)^2 + (pPos.y - mountY)^2 + (pPos.z - mountZ)^2))
                        if dist <= maxRange then
                            table.insert(newTargets, {
                                name = pName,
                                x = pPos.x,
                                y = pPos.y,
                                z = pPos.z,
                                distance = dist
                            })
                        end
                    end
                end
            end
            
            table.sort(newTargets, function(a, b) return a.distance < b.distance end)
            cachedTargets = newTargets
        else
            scanError = players
        end
        
        local gData = reader.getBlockData() or {}
        drawUI(gData.CannonYaw or 0, gData.CannonPitch or 0, nil, nil)
        os.sleep(uiTickRate) 
    end
end

-- ==========================================
-- LOOP 2: GUN MOTORS 
-- ==========================================
local function gunLoop()
    while true do
        local activeTarget = nil
        if #cachedTargets > 0 then activeTarget = cachedTargets[1] end

        local gunData = reader.getBlockData() or {}
        local currentYaw = gunData.CannonYaw or 0
        local currentPitch = gunData.CannonPitch or 0
        local targetYaw, targetPitch = nil, nil

        if activeTarget then
            local tX = activeTarget.x - mountX
            local tY = (activeTarget.y + 1.5) - mountY
            local tZ = activeTarget.z - mountZ
            local distXZ = math.sqrt(tX^2 + tZ^2)

            targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
            targetPitch = math.deg(math.atan2(tY, distXZ))
            if invertPitch then targetPitch = -targetPitch end

            local yawError = wrapAngle(targetYaw - currentYaw)
            local pitchError = targetPitch - currentPitch

            if yawError > deadzone then setRelay(yawPosRelay, false); setRelay(yawNegRelay, true)
            elseif yawError < -deadzone then setRelay(yawPosRelay, true); setRelay(yawNegRelay, false)
            else setRelay(yawPosRelay, false); setRelay(yawNegRelay, false) end

            if pitchError > deadzone then setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, true)
            elseif pitchError < -deadzone then setRelay(pitchPosRelay, true); setRelay(pitchNegRelay, false)
            else setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false) end

            local yawIsStopped = (yawError > -deadzone and yawError < deadzone)
            local pitchIsStopped = (pitchError > -deadzone and pitchError < deadzone)
            
            if yawIsStopped and pitchIsStopped then
                setRelay(fireRelay, true); sysStatus = "FIRING!"
            else
                setRelay(fireRelay, false); sysStatus = "TRACKING"
            end
        else
            setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            setRelay(fireRelay, false); sysStatus = "STANDBY"
        end
        
        if uiMode == "HUD" then
            drawUI(currentYaw, currentPitch, targetYaw, targetPitch)
        end
        os.sleep(logicTickRate) 
    end
end

-- ==========================================
-- LOOP 3: MOUSE CLICKS (GUI Interactions)
-- ==========================================
local function clickLoop()
    while true do
        local event, button, x, y = os.pullEvent("mouse_click")
        
        if uiMode == "HUD" then
            if y == 18 then
                uiMode = "WHITELIST"
                local gData = reader.getBlockData() or {}
                drawUI(gData.CannonYaw, gData.CannonPitch)
            end
        elseif uiMode == "WHITELIST" then
            if y == 18 then
                uiMode = "HUD"
                local gData = reader.getBlockData() or {}
                drawUI(gData.CannonYaw, gData.CannonPitch)
            elseif y >= 4 and y <= 15 then
                local clickedIndex = y - 3
                local pName = allOnlinePlayers[clickedIndex]
                
                if pName then
                    -- Toggle safety status
                    if whitelist[pName] then
                        whitelist[pName] = false
                    else
                        whitelist[pName] = true
                    end
                    saveWhitelist() -- Save immediately to the hard drive
                    
                    local gData = reader.getBlockData() or {}
                    drawUI(gData.CannonYaw, gData.CannonPitch)
                end
            end
        end
    end
end

term.clear()
parallel.waitForAll(radarLoop, gunLoop, clickLoop)
