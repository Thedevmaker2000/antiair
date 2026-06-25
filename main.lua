-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v7
-- (Omni-Power & Anti-Crash Edition)
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
local scanRange = 32 -- Restored to 32m
local yawOffset = 0 
local deadzone = 2.5 

local logicTickRate = 0.05 
local uiTickRate = 0.5      

local selectedTargetUUID = nil
local cachedEntities = {}

local function wrapAngle(angle)
    return (angle + 180) % 360 - 180
end

-- UPGRADE: Blast redstone out of every single side of the relay block
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
-- FLICKER-FREE UI DRAWING
-- ==========================================
local function drawUI()
    term.setCursorPos(1, 1)
    term.clearLine()
    print("=== RADAR TARGETING OS v7 ===")
    
    term.setCursorPos(1, 2)
    term.clearLine()
    print("Click target to lock. Range: " .. scanRange .. "m")
    
    for i = 1, 12 do
        term.setCursorPos(1, 2 + i)
        term.clearLine()
        
        local ent = cachedEntities[i]
        if ent then
            local dist = math.floor(math.sqrt(ent.x^2 + ent.y^2 + ent.z^2))
            local prefix = "[ ]"
            if ent.uuid == selectedTargetUUID then prefix = "[X]" end
            print(string.format("%d. %s %s (Dist: %dm)", i, prefix, ent.name, dist))
        else
            print("") -- Clear unused lines
        end
    end

    term.setCursorPos(1, 16)
    term.clearLine()
    print("---------------------------------------------")
    term.setCursorPos(1, 17)
    term.clearLine()
    print("[X] CLEAR CURRENT TARGET")
end

-- ==========================================
-- MAIN EVENT LOOP
-- ==========================================
local logicTimer = os.startTimer(logicTickRate)
local uiTimer = os.startTimer(uiTickRate)

term.clear()
drawUI()

while true do
    local event, p1, p2, p3 = os.pullEvent()

    -- ==============================
    -- 1. GUN MOVEMENT LOGIC
    -- ==============================
    if event == "timer" and p1 == logicTimer then
        
        local activeTarget = nil
        for _, ent in ipairs(cachedEntities) do
            if ent.uuid == selectedTargetUUID then
                activeTarget = ent
                break
            end
        end

        if activeTarget then
            local tX, tY, tZ = activeTarget.x, activeTarget.y, activeTarget.z
            local distXZ = math.sqrt(tX^2 + tZ^2)

            local targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
            local targetPitch = math.deg(math.atan2(tY, distXZ))

            local gunData = reader.getBlockData()
            local currentYaw = gunData.CannonYaw or 0
            local currentPitch = gunData.CannonPitch or 0

            local yawError = wrapAngle(targetYaw - currentYaw)
            local pitchError = targetPitch - currentPitch

            -- Yaw
            if yawError > deadzone then
                setRelay(yawPosRelay, true); setRelay(yawNegRelay, false)
            elseif yawError < -deadzone then
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, true)
            else
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            end

            -- Pitch
            if pitchError > deadzone then
                setRelay(pitchPosRelay, true); setRelay(pitchNegRelay, false)
            elseif pitchError < -deadzone then
                setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, true)
            else
                setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            end

            -- Fire
            if math.abs(yawError) <= deadzone and math.abs(pitchError) <= deadzone then
                setRelay(fireRelay, true)
            else
                setRelay(fireRelay, false)
            end
        else
            -- Safety weapon
            setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            setRelay(fireRelay, false)
        end
        
        logicTimer = os.startTimer(logicTickRate)

    -- ==============================
    -- 2. RADAR SCANNING (Safe Mode)
    -- ==============================
    elseif event == "timer" and p1 == uiTimer then
        
        -- UPGRADE: pcall prevents the cooldown crash. 
        local success, result = pcall(scanner.scanEntities, scanRange)
        
        -- If scan succeeds, update our list. If it fails (cooldown), we just ignore it!
        if success and type(result) == "table" then
            cachedEntities = result
            table.sort(cachedEntities, function(a, b)
                return (a.x^2 + a.y^2 + a.z^2) < (b.x^2 + b.y^2 + b.z^2)
            end)
            drawUI()
        end
        
        uiTimer = os.startTimer(uiTickRate)

    -- ==============================
    -- 3. MOUSE CLICKS
    -- ==============================
    elseif event == "mouse_click" then
        local button, x, y = p1, p2, p3
        
        if y == 17 then
            selectedTargetUUID = nil
            drawUI()
        elseif y >= 3 and y <= 14 then
            local clickedIndex = y - 2
            local clickedEntity = cachedEntities[clickedIndex]
            if clickedEntity then
                selectedTargetUUID = clickedEntity.uuid
                drawUI()
            end
        end
    end
end
