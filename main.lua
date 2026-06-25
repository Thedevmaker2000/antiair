-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v9.1
-- (Radar Fix & Diagnostics Patch)
-- ==========================================

local scanner = peripheral.find("environmentDetector")
local reader = peripheral.find("blockReader")

local yawPosRelay   = peripheral.wrap("redstone_relay_0") 
local yawNegRelay   = peripheral.wrap("redstone_relay_1") 
local pitchPosRelay = peripheral.wrap("redstone_relay_2") 
local pitchNegRelay = peripheral.wrap("redstone_relay_3") 
local fireRelay     = peripheral.wrap("redstone_relay_4") 

if not scanner or not reader then
    print("ERROR: Sensors offline. Check Wired Modems.")
    return
end

-- ==========================================
-- CALIBRATION
-- ==========================================
local scanRange = 16  
local yawOffset = 0   
local deadzone = 4.0  

local logicTickRate = 0.05 
-- FIXED: Slowed the radar sweep back down to bypass server cooldowns
local uiTickRate = 2.0      

local selectedTargetName = nil 
local cachedEntities = {}
local sysStatus = "STANDBY"
local radarStatus = "SWEEPING" -- New diagnostic variable

local function wrapAngle(angle)
    return (angle + 180) % 360 - 180
end

local function setRelay(relay, state)
    if relay then 
        pcall(function()
            relay.setOutput("top", state)
            relay.setOutput("bottom", state)
            relay.setOutput("left", state)
            relay.setOutput("right", state)
            relay.setOutput("front", state)
            relay.setOutput("back", state)
        end)
    end
end

-- ==========================================
-- REAL-TIME COMBAT HUD
-- ==========================================
local function drawUI(gunY, gunP, tarY, tarP, dist)
    term.setCursorPos(1, 1)
    term.clearLine()
    print("=== CIWS COMBAT OS v9.1 ===")
    
    term.setCursorPos(1, 2)
    term.clearLine()
    -- FIXED: Now shows if the radar is actively working or jammed
    print("SYS: " .. sysStatus .. " | RADAR: " .. radarStatus)

    term.setCursorPos(1, 3)
    term.clearLine()
    local gY_str = string.format("%.1f", gunY or 0)
    local gP_str = string.format("%.1f", gunP or 0)
    print("GUN POS -> Yaw: " .. gY_str .. " | Pitch: " .. gP_str)

    term.setCursorPos(1, 4)
    term.clearLine()
    if tarY and tarP then
        local tY_str = string.format("%.1f", tarY)
        local tP_str = string.format("%.1f", tarP)
        print("TGT POS -> Yaw: " .. tY_str .. " | Pitch: " .. tP_str .. " (" .. dist .. "m)")
    else
        print("TGT POS -> NO LOCK")
    end

    term.setCursorPos(1, 5)
    print("----------------------------------------")
    
    for i = 1, 10 do
        term.setCursorPos(1, 5 + i)
        term.clearLine()
        
        local ent = cachedEntities[i]
        if ent then
            local eDist = math.floor(math.sqrt(ent.x^2 + ent.y^2 + ent.z^2))
            local prefix = "[ ]"
            if ent.name == selectedTargetName then prefix = "[X]" end
            print(string.format("%d. %s %s (%dm)", i, prefix, ent.name, eDist))
        else
            print("") 
        end
    end

    term.setCursorPos(1, 17)
    term.clearLine()
    print("----------------------------------------")
    term.setCursorPos(1, 18)
    term.clearLine()
    print("[X] CLEAR TARGET (Auto-locks closest)")
end

-- ==========================================
-- MAIN EVENT LOOP
-- ==========================================
local logicTimer = os.startTimer(logicTickRate)
local uiTimer = os.startTimer(uiTickRate)

term.clear()

while true do
    local event, p1, p2, p3 = os.pullEvent()

    -- ==============================
    -- 1. GUN MOVEMENT LOGIC
    -- ==============================
    if event == "timer" and p1 == logicTimer then
        
        local activeTarget = nil
        
        if #cachedEntities > 0 then
            if selectedTargetName then
                for _, ent in ipairs(cachedEntities) do
                    if ent.name == selectedTargetName then
                        activeTarget = ent
                        break
                    end
                end
            else
                activeTarget = cachedEntities[1]
            end
        end

        local gunData = reader.getBlockData()
        local currentYaw = 0
        local currentPitch = 0
        if gunData then
            currentYaw = gunData.CannonYaw or 0
            currentPitch = gunData.CannonPitch or 0
        end

        if activeTarget then
            local tX, tY, tZ = activeTarget.x, activeTarget.y, activeTarget.z
            local distXZ = math.sqrt(tX^2 + tZ^2)
            local realDist = math.floor(math.sqrt(tX^2 + tY^2 + tZ^2))

            local targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
            local targetPitch = math.deg(math.atan2(tY, distXZ))

            local yawError = wrapAngle(targetYaw - currentYaw)
            local pitchError = targetPitch - currentPitch

            if yawError > deadzone then
                setRelay(yawPosRelay, true); setRelay(yawNegRelay, false)
                sysStatus = "TRACKING -> L"
            elseif yawError < -deadzone then
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, true)
                sysStatus = "TRACKING -> R"
            else
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            end

            if pitchError > deadzone then
                setRelay(pitchPosRelay, true); setRelay(pitchNegRelay, false)
            elseif pitchError < -deadzone then
                setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, true)
            else
                setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            end

            if math.abs(yawError) <= deadzone and math.abs(pitchError) <= deadzone then
                setRelay(fireRelay, true)
                sysStatus = "FIRING!"
            else
                setRelay(fireRelay, false)
                if sysStatus ~= "TRACKING -> L" and sysStatus ~= "TRACKING -> R" then
                    sysStatus = "TRACKING: ALIGNING PITCH"
                end
            end

            drawUI(currentYaw, currentPitch, targetYaw, targetPitch, realDist)
        else
            setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            setRelay(fireRelay, false)
            sysStatus = "STANDBY"
            drawUI(currentYaw, currentPitch, nil, nil, 0)
        end
        
        logicTimer = os.startTimer(logicTickRate)

    -- ==============================
    -- 2. RADAR SCANNING LOGIC
    -- ==============================
    elseif event == "timer" and p1 == uiTimer then
        
        local success, result = pcall(function() return scanner.scanEntities(scanRange) end)
        
        -- FIXED: If the scan fails, it will now visibly tell you on the HUD
        if success and type(result) == "table" then
            radarStatus = "OK"
            cachedEntities = result
            table.sort(cachedEntities, function(a, b)
                return (a.x^2 + a.y^2 + a.z^2) < (b.x^2 + b.y^2 + b.z^2)
            end)
        else
            radarStatus = "JAMMED (Cooldown/Range)"
        end
        
        uiTimer = os.startTimer(uiTickRate)

    -- ==============================
    -- 3. MOUSE CLICKS
    -- ==============================
    elseif event == "mouse_click" then
        local button, x, y = p1, p2, p3
        
        if y == 18 then
            selectedTargetName = nil
            sysStatus = "AUTO-TARGETING"
        elseif y >= 6 and y <= 15 then
            local clickedIndex = y - 5
            local clickedEntity = cachedEntities[clickedIndex]
            if clickedEntity then
                selectedTargetName = clickedEntity.name
                sysStatus = "MANUAL LOCK"
            end
        end
    end
end
