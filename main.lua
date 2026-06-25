-- ==========================================
-- ANTI-AIR TURRET FIRE CONTROL SYSTEM v4
-- (Threat Identification Edition)
-- ==========================================

local scanner = peripheral.find("environment_detector")
local reader = peripheral.find("block_reader")

if not scanner or not reader then
    print("ERROR: Sensors offline. Check Wired Modems.")
    return
end

-- ==========================================
-- 1. THREAT DATABASE (Customize this!)
-- ==========================================
-- Type the exact names of what you want the turret to shoot.
-- Be careful with player names, capitalization matters!
local validTargets = {
    "Zombie",
    "Skeleton",
    "Creeper",
    "Phantom",
    "Ghast",
    "Witch"
    -- "PlayerName1", (Uncomment and add enemies here)
}

-- ==========================================
-- 2. CALIBRATION VARIABLES
-- ==========================================
local scanRange = 32
local yawOffset = 0 
local deadzone = 2.5 

local YAW_POS = "left"
local YAW_NEG = "right"
local PITCH_POS = "top"
local PITCH_NEG = "bottom"
local FIRE_PIN = "back"

-- ==========================================
-- 3. UTILITY FUNCTIONS
-- ==========================================
local function wrapAngle(angle)
    return (angle + 180) % 360 - 180
end

-- This function checks the scanner list against your Threat Database
local function acquireTarget(entityList)
    if not entityList then return nil end
    
    for _, entity in ipairs(entityList) do
        for _, threatName in ipairs(validTargets) do
            if entity.name == threatName then
                return entity -- Target Acquired!
            end
        end
    end
    return nil -- No valid threats found
end

print("Sensors Online. Threat Filter Active.")

-- ==========================================
-- 4. MAIN CONTROL LOOP
-- ==========================================
while true do
    local allEntities = scanner.scanEntities(scanRange)
    
    -- Pass the raw list through our Threat Filter
    local target = acquireTarget(allEntities)
    
    if target then
        -- Target locked. Calculate interception.
        local tX, tY, tZ = target.x, target.y, target.z
        local distXZ = math.sqrt(tX^2 + tZ^2)

        local targetYaw = math.deg(math.atan2(-tX, tZ)) + yawOffset
        local targetPitch = math.deg(math.atan2(tY, distXZ))

        local gunData = reader.getBlockData()
        local currentYaw = gunData.CannonYaw
        local currentPitch = gunData.CannonPitch

        local yawError = wrapAngle(targetYaw - currentYaw)
        local pitchError = targetPitch - currentPitch

        -- Yaw Control
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

        -- Pitch Control
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

        -- Firing Solution
        if math.abs(yawError) <= deadzone and math.abs(pitchError) <= deadzone then
            rs.setOutput(FIRE_PIN, true)
        else
            rs.setOutput(FIRE_PIN, false)
        end

    else
        -- Standby Mode
        rs.setOutput(YAW_POS, false)
        rs.setOutput(YAW_NEG, false)
        rs.setOutput(PITCH_POS, false)
        rs.setOutput(PITCH_NEG, false)
        rs.setOutput(FIRE_PIN, false)
    end

    os.sleep(0.05) 
end
