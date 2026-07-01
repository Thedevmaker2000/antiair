-- ==========================================
-- REMOTE ARTILLERY CLIENT (POCKET PC)
-- ==========================================

-- Open the built-in pocket modem
peripheral.find("modem", function(name) rednet.open(name) end)

-- ==========================================
-- 1. CALIBRATION ZONE 
-- ==========================================
local VELOCITY_PER_CHARGE = 2.0 
local VELOCITY_PER_BARREL = 0.1 
local GRAVITY = 0.05            

-- Hardcoded so you don't have to type them every time!
local BARREL_LENGTH = 10 
local YAW_OFFSET = 0

-- ==========================================

local function wrapAngle(angle) return (angle + 180) % 360 - 180 end

term.clear()
term.setCursorPos(1,1)
print("== POCKET ICBM UPLINK ==")
print("Searching for Firebase...")

-- Auto-Discover the Server
rednet.broadcast({cmd = "GET_INFO"}, "CBC_ARTILLERY")
local serverId, info = rednet.receive("CBC_ARTILLERY", 3)

if not serverId then
    print("ERROR: No Cannon Server found.")
    print("Are chunks loaded?")
    return
end

print("Uplink Active! [ID: " .. serverId .. "]")
local cX, cY, cZ = info.x, info.y, info.z

-- ==========================================
-- 2. GET STRIKE COORDINATES
-- ==========================================
print("------------------------")
print("Target X:")
local tX = tonumber(io.read())
print("Target Z:")
local tZ = tonumber(io.read())
print("Target Y (Elevation):")
local tY = tonumber(io.read())

print("Powder Charges:")
local charges = tonumber(io.read())

-- ==========================================
-- 3. BALLISTIC MATH
-- ==========================================
local dx = tX - cX
local dy = tY - cY
local dz = tZ - cZ
local distXZ = math.sqrt(dx^2 + dz^2)

local v = (charges * VELOCITY_PER_CHARGE) + (BARREL_LENGTH * VELOCITY_PER_BARREL)
local g = GRAVITY
local root = v^4 - g * (g * distXZ^2 + 2 * dy * v^2)

term.clear()
term.setCursorPos(1,1)

if root < 0 then
    print("== SOLUTION FAILED ==")
    print("OUT OF RANGE!")
    return
end

local pitchRad = math.atan((v^2 - math.sqrt(root)) / (g * distXZ))
local targetPitch = math.deg(pitchRad) 
local targetYaw = math.deg(math.atan2(-dx, dz)) + YAW_OFFSET
targetYaw = (targetYaw % 360 + 360) % 360

local vX = v * math.cos(pitchRad) 
local airtimeTicks = math.floor(distXZ / vX)

-- ==========================================
-- 4. REMOTE EXECUTION
-- ==========================================
print("Tgt : " .. math.floor(distXZ) .. "m away")
print("Yaw : " .. string.format("%.1f", targetYaw))
print("Ptch: " .. string.format("%.1f", targetPitch))
print("Fuze: " .. airtimeTicks .. " ticks")

print("\n[C] to Cancel, [Enter] to Assemble.")
if io.read() == "c" then return end

rednet.send(serverId, {cmd = "ASSEMBLE", state = true}, "CBC_ARTILLERY")
print("Sending Aim Data...")
rednet.send(serverId, {cmd = "AIM", yaw = targetYaw, pitch = targetPitch}, "CBC_ARTILLERY")

-- LIVE TELEMETRY LOOP
while true do
    rednet.send(serverId, {cmd = "GET_INFO"}, "CBC_ARTILLERY")
    local _, curInfo = rednet.receive("CBC_ARTILLERY", 2)
    
    if curInfo then
        local curYaw = (curInfo.yaw % 360 + 360) % 360
        local curPitch = curInfo.pitch
        
        local yDiff = math.abs(wrapAngle(targetYaw - curYaw))
        local pDiff = math.abs(targetPitch - curPitch)
        
        local x, y = term.getCursorPos()
        term.setCursorPos(1, y)
        term.clearLine()
        term.write(string.format("Y: %.1f | P: %.1f", curYaw, curPitch))
        
        if yDiff <= 0.5 and pDiff <= 0.5 then
            print("\n\n!! TARGET LOCKED !!")
            break
        end
    else
        print("\nConnection lost during alignment!")
        return
    end
    os.sleep(0.1)
end

print("\nType 'FIRE' to launch:")
if io.read() == "FIRE" then
    rednet.send(serverId, {cmd = "FIRE", state = true}, "CBC_ARTILLERY")
    os.sleep(0.5)
    rednet.send(serverId, {cmd = "FIRE", state = false}, "CBC_ARTILLERY")
    print("\n>> SPLASH INBOUND <<")
end
