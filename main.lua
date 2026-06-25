-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM
-- (V8 Baseline + Auto-Lock Fix)
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
local scanRange = 16  -- Hard-capped to 16 to prevent server config crashes
local yawOffset = 0 
local deadzone = 4.0  -- Slightly increased to stop 128 RPM jitter

local logicTickRate = 0.05  -- Gun motors run at 20 ticks per second
local uiTickRate = 1.5      -- Radar sweeps every 1.5 seconds

local cachedEntities = {}
local scanError = nil

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
-- UI DRAWING LOGIC
-- ==========================================
local function drawUI()
    term.setCursorPos(1, 1)
    term.clearLine()
    print("=== CIWS TARGETING OS (AUTO-LOCK) ===")
    
    term.setCursorPos(1, 2)
    term.clearLine()
    if scanError then
        print("RADAR STATUS: " .. tostring(scanError))
    else
        print("RADAR STATUS: Sweeping (" .. scanRange .. "m)...")
    end
    
    for i = 1, 12 do
        term.setCursorPos(1, 3 + i)
        term.clearLine()
        
        local ent = cachedEntities[i]
        if ent then
            local dist = math.floor(math.sqrt(ent.x^2 + ent.y^2 + ent.z^2))
            local prefix = "[ ]"
            -- Visually highlight the closest entity that the gun is locking onto
            if i == 1 then prefix = "[X]" end 
            print(string.format("%d. %s %s (Dist: %dm)", i, prefix, ent.name, dist))
        else
            print("") 
        end
    end

    term.setCursorPos(1, 17)
    term.clearLine()
    print("---------------------------------------------")
    term.setCursorPos(1, 18)
    term.clearLine()
    print("WARNING: STAND CLEAR. TURRET IS LIVE.")
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
        
        -- THE FIX: Completely bypass mouse clicks. Always grab the closest target.
        local activeTarget = nil
        if #cachedEntities > 0 then
            activeTarget = cachedEntities[1]
        end

        if activeTarget then
            local tX, tY, tZ = activeTarget.x, activeTarget.y, activeTarget.z
            local distXZ = math.sqrt(tX^2 + tZ^2)

            local targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
            local targetPitch = math.deg(math.atan2(tY, distXZ))

            -- Added a safety fallback in case the block reader glitches
            local gunData = reader.getBlockData() or {}
            local currentYaw = gunData.CannonYaw or 0
            local currentPitch = gunData.CannonPitch or 0

            local yawError = wrapAngle(targetYaw - currentYaw)
            local pitchError = targetPitch - currentPitch

            -- Yaw Control
            if yawError > deadzone then
                setRelay(yawPosRelay, true); setRelay(yawNegRelay, false)
            elseif yawError < -deadzone then
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, true)
            else
                setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            end

            -- Pitch Control
            if pitchError > deadzone then
                setRelay(pitchPosRelay, true); setRelay(pitchNegRelay, false)
            elseif pitchError < -deadzone then
                setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, true)
            else
                setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            end

            -- Firing Control
            if math.abs(yawError) <= deadzone and math.abs(pitchError) <= deadzone then
                setRelay(fireRelay, true)
            else
                setRelay(fireRelay, false)
            end
        else
            -- Safety weapon mode (No Targets)
            setRelay(yawPosRelay, false); setRelay(yawNegRelay, false)
            setRelay(pitchPosRelay, false); setRelay(pitchNegRelay, false)
            setRelay(fireRelay, false)
        end
        
        logicTimer = os.startTimer(logicTickRate)

    -- ==============================
    -- 2. RADAR SCANNING LOGIC
    -- ==============================
    elseif event == "timer" and p1 == uiTimer then
        
        local success, result = pcall(function() 
            return scanner.scanEntities(scanRange) 
        end)
        
        if success and type(result) == "table" then
            scanError = nil
            cachedEntities = result
            table.sort(cachedEntities, function(a, b)
                return (a.x^2 + a.y^2 + a.z^2) < (b.x^2 + b.y^2 + b.z^2)
            end)
        else
            scanError = result
        end
        
        drawUI()
        uiTimer = os.startTimer(uiTickRate)
    end
    -- Mouse clicks completely removed to prevent UI lockups
end
