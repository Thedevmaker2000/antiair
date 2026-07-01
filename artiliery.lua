-- ==========================================
-- CBC AUTO-ARTILLERY FIRE CONTROL
-- (Direct API Integration & Ballistic Math)
-- ==========================================

local cannon = peripheral.find("cannon_mount")
if not cannon then
    print("ERROR: No cannon_mount found! Check modem connection.")
    return
end

-- Force the cannon into computer control mode
cannon.setComputerControl(true)

-- ==========================================
-- 1. CALIBRATION (Tweak these for your server)
-- ==========================================
-- CBC velocity depends heavily on material (Bronze, Steel, etc.) and config.
-- Adjust this number if your shots are consistently overshooting or undershooting.
local VELOCITY_PER_CHARGE = 2.0 -- Blocks per tick per powder charge
local VELOCITY_PER_BARREL = 0.1 -- Extra speed added per barrel block
local GRAVITY = 0.05            -- CBC default gravity per tick

-- ==========================================
-- 2. GET USER INPUTS
-- ==========================================
term.clear()
term.setCursorPos(1,1)
print("=== CBC ARTILLERY OS ===")

-- Auto-fetch mount position!
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

-- Calculate Muzzle Velocity
local v = (charges * VELOCITY_PER_CHARGE) + (barrelLength * VELOCITY_PER_BARREL)
local g = GRAVITY

-- The Ballistic Arc Equation
local root = v^4 - g * (g * distXZ^2 + 2 * dy * v^2)

term.clear()
term.setCursorPos(1,1)

if root < 0 then
    print("=== FIRING SOLUTION FAILED ===")
    print("TARGET IS OUT OF RANGE!")
    print("Increase charges or move closer.")
    return
end

-- Calculate Pitch (Using the lower arc trajectory)
local pitchRad = math.atan((v^2 - math.sqrt(root)) / (g * distXZ))

-- CC:CBC usually treats looking UP as a positive angle, but if your 
-- physical mount is inverted, you may need to add a minus sign here:
local targetPitch = math.deg(pitchRad) 
local targetYaw = math.deg(math.atan2(-dx, dz)) + yawOffset

-- Calculate Airtime
local vX = v * math.cos(pitchRad) -- Horizontal velocity component
local airtimeTicks = math.floor(distXZ / vX)
local airtimeSeconds = airtimeTicks / 20

-- Calculate Relative Precision (Estimates spread based on distance & barrel)
local precisionRaw = 100 - (distXZ / (barrelLength * 5))
local precision = math.max(0, math.min(100, precisionRaw))

-- ==========================================
-- 4. EXECUTION
-- ==========================================
print("=== FIRING SOLUTION ACQUIRED ===")
print(string.format("Target Range : %dm", math.floor(distXZ)))
print(string.format("Calculated V0: %.2f blocks/tick", v))
print("--------------------------------")
print(string.format("Yaw          : %.2f deg", targetYaw))
print(string.format("Pitch        : %.2f deg", targetPitch))
print(string.format("Airtime      : %d ticks (%.2f sec)", airtimeTicks, airtimeSeconds))
print(string.format("Fuze Setting : %d ticks", airtimeTicks))
print(string.format("Rel. Precision: %.1f%%", precision))
print("--------------------------------")

print("\nAssemble Cannon? (y/n)")
if io.read() == "y" then
    local isAssembled = cannon.assemble(true)
    if not isAssembled then
        print("WARNING: Cannon failed to assemble. Check blocks.")
    else
        print("Cannon assembled.")
    end
end

print("\nAim Cannon? (y/n)")
if io.read() == "y" then
    -- No more relays! We just tell the API where to look.
    cannon.setTargetAngles(targetYaw, targetPitch)
    print("Motors engaged. Waiting for alignment...")
end

print("\nFIRE? (y/n)")
if io.read() == "y" then
    cannon.fire(true)
    os.sleep(0.5) -- Hold the trigger for half a second
    cannon.fire(false)
    print("SHOT OUT.")
end
