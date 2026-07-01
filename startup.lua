-- ==========================================
-- CBC AUTO-ARTILLERY FIRE CONTROL v14.1
-- (Smart Alignment & Telemetry Edition)
-- ==========================================

local cannon = peripheral.find("cannon_mount")
if not cannon then
    print("ERROR: No cannon_mount found! Check modem connection.")
    return
end

cannon.setComputerControl(true)

-- ==========================================
-- 1. CALIBRATION (Tweak Velocity for Steel)
-- ==========================================
local VELOCITY_PER_CHARGE = 2.0 
local VELOCITY_PER_BARREL = 0.1 
local GRAVITY = 0.05            

local function wrapAngle(angle)
    return (angle + 180) % 360 - 180
end

-- ==========================================
-- 2. GET USER INPUTS
-- ==========================================
term.clear()
term.setCursorPos(1,1)
print("=== CBC ARTILLERY OS ===")

local info = cannon.getInfo()
local cX, cY, cZ = info.x, info.y, info.z
print("[+] Mount Pos: " .. cX .. ", " .. cY .. ", " .. cZ)
print("------------------------")

print("Target X:")
local tX = tonumber(io.read())
print("Target Y:")
local tY = tonumber(io.read())
print("Target Z:")
local tZ = tonumber(io.read())

print("Number of Charges:")
local charges = tonumber(io.read())

print("Barrel Length (Blocks):")
local barrelLength = tonumber(io.read())

print("Unmounted Direction (0=S, 90=W, 180=N, -90=E):")
local yawOffset = tonumber(io.read())

-- ==========================================
-- 3. TRAJECTORY CALCULATIONS
-- ==========================================
local dx = tX - cX
local dy = tY - cY
local dz = tZ - cZ
local distXZ = math.sqrt(dx^2 + dz^2)

local v = (charges * VELOCITY_PER_CHARGE) + (barrelLength * VELOCITY_PER_BARREL)
local g = GRAVITY

local root = v^4 - g * (g * distXZ^2 + 2 * dy * v^2)

term.clear()
term.setCursorPos(1,1)

if root < 0 then
    print("=== FIRING SOLUTION FAILED ===")
    print("TARGET IS OUT OF RANGE!")
    print("Increase powder charges.")
    return
end

local pitchRad = math.atan((v^2 - math.sqrt(root)) / (g * distXZ))
local targetPitch = math.deg(pitchRad) 
local targetYaw = math.deg(math.atan2(-dx, dz)) + yawOffset

-- Normalize target yaw to be within standard 360 bounds
targetYaw = (targetYaw % 360 + 360) % 360

local vX = v * math.cos(pitchRad) 
local airtimeTicks = math.floor(distXZ / vX)

-- ==========================================
-- 4. EXECUTION & ALIGNMENT
-- ==========================================
print("=== FIRING SOLUTION ACQUIRED ===")
print(string.format("Target Range : %dm", math.floor(distXZ)))
print("--------------------------------")
print(string.format("Yaw          : %.2f deg", targetYaw))
print(string.format("Pitch        : %.2f deg", targetPitch))
print(string.format("Fuze Setting : %d ticks", airtimeTicks))
print("--------------------------------")

print("\nAssemble Cannon? (y/n)")
if io.read() == "y" then
    cannon.assemble(true)
    print("Cannon assembled.")
end

print("\nAim Cannon? (y/n)")
if io.read() == "y" then
    cannon.setTargetAngles(targetYaw, targetPitch)
    print("\n[ ALIGNING MOTORS... ]")
    
    -- THE ALIGNMENT LOOP: Waits for the cannon to finish moving
    while true do
        local curInfo = cannon.getInfo()
        local curYaw = (curInfo.yaw % 360 + 360) % 360
        local curPitch = curInfo.pitch
        
        local yDiff = math.abs(wrapAngle(targetYaw - curYaw))
        local pDiff = math.abs(targetPitch - curPitch)
        
        -- Print real-time telemetry over the same line to prevent spam
        local x, y = term.getCursorPos()
        term.setCursorPos(1, y)
        term.clearLine()
        term.write(string.format("Current -> Yaw: %.1f | Pitch: %.1f", curYaw, curPitch))
        
        -- If we are within 0.5 degrees of the target, we are locked on
        if yDiff <= 0.5 and pDiff <= 0.5 then
            print("\n\nTARGET LOCKED.")
            break
        end
        
        os.sleep(0.1)
    end
end

print("\nFIRE? (y/n)")
if io.read() == "y" then
    -- We can still keep Relay 4 for firing if your physical firing mechanism needs it,
    -- but CC:CBC has a built-in fire command!
    cannon.fire(true)
    os.sleep(0.5) 
    cannon.fire(false)
    print("SHOT OUT.")
end
