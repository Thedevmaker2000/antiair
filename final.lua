-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v11
-- (Parallax & Calibration Edition)
-- ==========================================

local scanner = peripheral.find("environmentDetector")
local reader = peripheral.find("blockReader")

local yawPosRelay   = peripheral.wrap("redstone_relay_0") 
local yawNegRelay   = peripheral.wrap("redstone_relay_1") 
local pitchPosRelay = peripheral.wrap("redstone_relay_2") 
local pitchNegRelay = peripheral.wrap("redstone_relay_3") 
local fireRelay     = peripheral.wrap("redstone_relay_4") 

if not scanner or not reader then
    print("ERROR: Sensors offline. Check modems.")
    return
end

-- ==========================================
-- 1. CALIBRATION ZONE (ADJUST THESE!)
-- ==========================================
local scanRange = 16  
local yawOffset = 0    -- Change to 90, 180, or -90 if the gun aims sideways/backwards
local invertPitch = false -- Change to 'true' if the gun aims UP when the target is DOWN

-- TEMPORARY: Increased to 10 degrees so it actually fires while you test it
local deadzone = 10.0  

-- THE PARALLAX FIX: Where is the Cannon Mount relative to the Scanner?
-- e.g., If the mount is 2 blocks ABOVE the scanner, sOffsetY = 2
local sOffsetX = 0 
local sOffsetY = 0 
local sOffsetZ = 0 

-- ==========================================

local logicTickRate = 0.05  
local uiTickRate = 1.5      

local cachedEntities = {}
local scanError = nil
local sysStatus = "STANDBY"

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
    term.setCursorPos(1, 1)
    term.clearLine()
    print("=== CIWS CALIBRATION OS v11 ===")
    
    term.setCursorPos(1, 2)
    term.clearLine()
    if scanError then print("RADAR: " .. tostring(scanError)) else print("RADAR: SWEEPING | SYS: " .. sysStatus) end
    
    -- DIAGNOSTICS: Compare these numbers to calibrate!
    term.setCursorPos(1, 3)
    term.clearLine()
    print(string.format("GUN IS AT -> Yaw: %.1f | Pitch: %.1f", gunY or 0, gunP or 0))
    term.setCursorPos(1, 4)
    term.clearLine()
    if tarY then
        print(string.format("MATH WANTS-> Yaw: %.1f | Pitch: %.1f", tarY, tarP))
    else
        print("MATH WANTS-> NO TARGET")
    end

    term.setCursorPos(1, 5)
    print("----------------------------------------")
    
    for i = 1, 10 do
        term.setCursorPos(1, 5 + i)
        term.clearLine()
        local ent = cachedEntities[i]
        if ent then
            local dist = math.floor(math.sqrt(ent.x^2 + ent.y^2 + ent.z^2))
            local prefix = "[ ]"
            if i == 1 then prefix = "[X]" end 
            print(string.format("%d. %s %s (%dm)", i, prefix, ent.name, dist))
        else
            print("") 
        end
    end
end

-- ==========================================
-- LOOP 1: RADAR 
-- ==========================================
local function radarLoop()
    while true do
        local success, result = pcall(function() return scanner.scanEntities(scanRange) end)
        if success and type(result) == "table" then
            scanError = nil; cachedEntities = result
            table.sort(cachedEntities, function(a, b) return (a.x^2 + a.y^2 + a.z^2) < (b.x^2 + b.y^2 + b.z^2) end)
        else
            scanError = result
        end
        os.sleep(uiTickRate) 
    end
end

-- ==========================================
-- LOOP 2: GUN MOTORS 
-- ==========================================
local function gunLoop()
    while true do
        local activeTarget = nil
        if #cachedEntities > 0 then activeTarget = cachedEntities[1] end

        local gunData = reader.getBlockData() or {}
        local currentYaw = gunData.CannonYaw or 0
        local currentPitch = gunData.CannonPitch or 0
        local targetYaw, targetPitch = nil, nil

        if activeTarget then
            -- Apply the Parallax Offset
            local tX = activeTarget.x - sOffsetX
            local tY = activeTarget.y - sOffsetY
            local tZ = activeTarget.z - sOffsetZ
            local distXZ = math.sqrt(tX^2 + tZ^2)

            targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
            targetPitch = math.deg(math.atan2(tY, distXZ))
            if invertPitch then targetPitch = -targetPitch end

            local yawError = wrapAngle(targetYaw - currentYaw)
            local pitchError = targetPitch - currentPitch

            if yawError > deadzone then setRelay(yawPosRelay, true); setRelay(yawNegRelay, false)
            elseif yawError < -deadzone then setRelay(yawPosRelay, false); setRelay(yawNegRelay, true)
            else setRelay(yawPosRelay, false); setRelay(yawNegRelay, false) end

            if pitchError > deadzone then setRelay(pitchPosRelay, true); setRelay(pitchNegRelay, false)
            elseif pitchError < -deadzone then setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, true)
            else setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false) end

            if math.abs(yawError) <= deadzone and math.abs(pitchError) <= deadzone then
                setRelay(fireRelay, true); sysStatus = "FIRING!"
            else
                setRelay(fireRelay, false); sysStatus = "TRACKING"
            end
        else
            setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            setRelay(fireRelay, false); sysStatus = "STANDBY"
        end
        
        drawUI(currentYaw, currentPitch, targetYaw, targetPitch)
        os.sleep(logicTickRate) 
    end
end

term.clear()
parallel.waitForAll(radarLoop, gunLoop)
