-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v5
-- (Interactive Targeting OS Edition)
-- ==========================================

local scanner = peripheral.find("environment_detector")
local reader = peripheral.find("block_reader")

-- Map the 5 specific relays
local yawPosRelay   = peripheral.wrap("redstone_relay_0") -- Left
local yawNegRelay   = peripheral.wrap("redstone_relay_1") -- Right
local pitchPosRelay = peripheral.wrap("redstone_relay_2") -- Up
local pitchNegRelay = peripheral.wrap("redstone_relay_3") -- Down
local fireRelay     = peripheral.wrap("redstone_relay_4") -- Fire

if not scanner or not reader then
    print("ERROR: Sensors offline. Check Wired Modems.")
    return
end

-- ==========================================
-- CALIBRATION & STATE
-- ==========================================
local scanRange = 32
local yawOffset = 0 
local deadzone = 2.5 
local tickRate = 0.05 -- 20 times a second

-- UI State
local selectedTargetUUID = nil
local cachedEntities = {}

-- Utility: Wrap angle to -180/180
local function wrapAngle(angle)
    return (angle + 180) % 360 - 180
end

-- Utility: Toggle relay power
-- NOTE: If your relays emit from a specific face, change "front" to "top", "bottom", etc.
local function setRelay(relay, state)
    if relay then relay.setOutput("front", state) end
end

-- ==========================================
-- UI DRAWING LOGIC
-- ==========================================
local function drawUI()
    term.clear()
    term.setCursorPos(1, 1)
    print("=== RADAR TARGETING OS ===")
    print("Click a target to lock on. Click [X] to clear.")
    print("---------------------------------------------")
    
    if #cachedEntities == 0 then
        print("No entities detected in range (" .. scanRange .. "m).")
        return
    end

    for i, entity in ipairs(cachedEntities) do
        -- Only show top 12 to fit on a standard monitor
        if i > 12 then break end 

        local dist = math.floor(math.sqrt(entity.x^2 + entity.y^2 + entity.z^2))
        local prefix = "[ ]"
        
        if entity.uuid == selectedTargetUUID then
            prefix = "[X]" -- Highlight locked target
        end
        
        print(string.format("%d. %s %s (Dist: %dm)", i, prefix, entity.name, dist))
    end
    
    print("---------------------------------------------")
    term.setCursorPos(1, 18)
    print("[X] CLEAR CURRENT TARGET")
end

-- ==========================================
-- MAIN EVENT LOOP
-- ==========================================
local timerId = os.startTimer(tickRate)

drawUI()

while true do
    -- Wait for either a timer tick or a mouse click
    local event, p1, p2, p3 = os.pullEvent()

    -- ==============================
    -- 1. AIMING & SCANNING LOGIC
    -- ==============================
    if event == "timer" and p1 == timerId then
        -- Refresh entities and sort by closest distance
        local rawEntities = scanner.scanEntities(scanRange) or {}
        table.sort(rawEntities, function(a, b)
            local distA = a.x^2 + a.y^2 + a.z^2
            local distB = b.x^2 + b.y^2 + b.z^2
            return distA < distB
        end)
        cachedEntities = rawEntities
        
        drawUI()

        -- Find the actively selected target
        local activeTarget = nil
        for _, ent in ipairs(cachedEntities) do
            if ent.uuid == selectedTargetUUID then
                activeTarget = ent
                break
            end
        end

        -- If target is valid and in range, aim and fire
        if activeTarget then
            local tX, tY, tZ = activeTarget.x, activeTarget.y, activeTarget.z
            local distXZ = math.sqrt(tX^2 + tZ^2)

            local targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
            local targetPitch = math.deg(math.atan2(tY, distXZ))

            local gunData = reader.getBlockData()
            local currentYaw = gunData.CannonYaw
            local currentPitch = gunData.CannonPitch

            local yawError = wrapAngle(targetYaw - currentYaw)
            local pitchError = targetPitch - currentPitch

            -- Yaw (Left/Right)
            if yawError > deadzone then
                setRelay(yawPosRelay, true); setRelay(yawNegRelay, false)
            elseif yawError < -deadzone then
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, true)
            else
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            end

            -- Pitch (Up/Down)
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
            -- No target selected or target moved out of range
            setRelay(yawPosRelay, false)
            setRelay(yawNegRelay, false)
            setRelay(pitchPosRelay, false)
            setRelay(pitchNegRelay, false)
            setRelay(fireRelay, false)
            selectedTargetUUID = nil -- Clear invalid target
        end

        -- Restart the loop timer
        timerId = os.startTimer(tickRate)

    -- ==============================
    -- 2. MOUSE CLICK LOGIC
    -- ==============================
    elseif event == "mouse_click" then
        local button, x, y = p1, p2, p3
        
        -- Check if they clicked the "CLEAR TARGET" button on line 18
        if y == 18 then
            selectedTargetUUID = nil
            drawUI()
        
        -- Check if they clicked a valid entity row (rows 4 through 4+number of entities)
        elseif y >= 4 and y < 4 + #cachedEntities then
            local clickedIndex = y - 3
            local clickedEntity = cachedEntities[clickedIndex]
            
            if clickedEntity then
                -- Lock on to the specific UUID of that entity
                selectedTargetUUID = clickedEntity.uuid
                drawUI()
            end
        end
    end
end
