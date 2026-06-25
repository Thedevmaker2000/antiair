-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v2
-- (Redstone Link Edition)
-- ==========================================

local scanner = peripheral.find("environmentDetector")
local reader = peripheral.find("blockReader")

-- Calibration Variables
local gX, gY, gZ = 2544, -60, 1323
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

while true do
    local targets = scanner.scanEntities()
    
    if targets and #targets > 0 then
        local target = targets[1] 
        local tX, tY, tZ = target.x, target.y, target.z

        -- Calculate distance and angles
        local dx = tX - gX
        local dy = tY - gY
        local dz = tZ - gZ
        local distXZ = math.sqrt(dx^2 + dz^2)

        local targetYaw = math.deg(math.atan2(-dx, dz)) + yawOffset
        local targetPitch = math.deg(math.atan2(dy, distXZ))

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
