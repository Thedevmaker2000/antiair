-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v3
-- (Relative Coordinate Edition)
-- ==========================================

-- 1. Initialize Peripherals with Safety Checks
local scanner = peripheral.find("environmentDetector")
local reader = peripheral.find("blockReader")

if not scanner or not reader then
    print("ERROR: Sensors offline.")
    print("Right-click all Wired Modems to turn them on (red ring).")
    return
end

print("Sensors Online. AA System Active.")

-- 2. Calibration Variables
local scanRange = 32 -- Maximum radius to scan for targets
local yawOffset = 0 -- Change to 90, 180, or -90 if the gun aims backwards
local deadzone = 2.5 -- Degrees of tolerance before firing

-- Side definitions for Redstone Transmitters
local YAW_POS = "left"
local YAW_NEG = "right"
local PITCH_POS = "top"
local PITCH_NEG = "bottom"
local FIRE_PIN = "back"

local function wrapAngle(angle)
    return (angle + 180) % 360 - 180
end

-- 3. Main Control Loop
while true do
    -- We now pass the scanRange into the function!
    local targets = scanner.scanEntities(scanRange)
    
    if targets and #targets > 0 then
        local target = targets[1] 
        
        -- Because coordinates are relative, tX, tY, tZ ARE the deltas!
        local tX, tY, tZ = target.x, target.y, target.z

        -- Calculate distance and angles
        local distXZ = math.sqrt(tX^2 + tZ^2)

        local targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
        local targetPitch = math.deg(math.atan2(tY, distXZ))

        -- Read current gun state
        local gunData = reader.getBlockData()
        local currentYaw = gunData.CannonYaw
        local currentPitch = gunData.CannonPitch

        local yawError = wrapAngle(targetYaw - currentYaw)
        local pitchError = targetPitch - currentPitch

        -- Yaw Control (Directional Gearshift 1)
        if yawError > deadzone then
            rs.setOutput(YAW_POS, true)
            rs.setOutput(YAW_NEG, false)
        elseif yawError < -deadzone then
            rs.setOutput(YAW_POS, false)
            rs.setOutput(YAW_NEG, true)
        else
            rs.setOutput(YAW_POS, false)
            rs.setOutput(YAW_NEG, false)
        end

        -- Pitch Control (Directional Gearshift 2)
        if pitchError > deadzone then
            rs.setOutput(PITCH_POS, true)
            rs.setOutput(PITCH_NEG, false)
        elseif pitchError < -deadzone then
            rs.setOutput(PITCH_POS, false)
            rs.setOutput(PITCH_NEG, true)
        else
            rs.setOutput(PITCH_POS, false)
            rs.setOutput(PITCH_NEG, false)
        end

        -- Firing Solution: Open fire if aimed within the deadzone
        if math.abs(yawError) <= deadzone and math.abs(pitchError) <= deadzone then
            rs.setOutput(FIRE_PIN, true)
        else
            rs.setOutput(FIRE_PIN, false)
        end

    else
        -- Standby Mode: No targets detected, cut all power
        rs.setOutput(YAW_POS, false)
        rs.setOutput(YAW_NEG, false)
        rs.setOutput(PITCH_POS, false)
        rs.setOutput(PITCH_NEG, false)
        rs.setOutput(FIRE_PIN, false)
    end

    os.sleep(0.05) 
end
