-- ==========================================
-- REMOTE ARTILLERY CLIENT (POCKET PC) v17
-- (Enhanced Shells & Multi-Tier Powder)
-- ==========================================

peripheral.find("modem", function(name) rednet.open(name) end)

-- ==========================================
-- 1. CALIBRATION ZONE 
-- ==========================================
local BARREL_LENGTH = 10 
local YAW_OFFSET = -140 
local VELOCITY_PER_BARREL = 0.1 

-- ==========================================
local function wrapAngle(angle) return (angle + 180) % 360 - 180 end

local function timeInAir(y0, targetY, initialVy)
    local y = y0
    local vy = initialVy
    local t = 0
    local t_below = 999999
    
    if y <= targetY then
        while t < 10000 do
            y = y + vy
            vy = 0.99 * vy - 0.05
            t = t + 1
            if y > targetY then
                t_below = t - 1
                break
            end
            if vy < 0 then return -1, -1 end
        end
    end
    
    while t < 10000 do
        y = y + vy
        vy = 0.99 * vy - 0.05
        t = t + 1
        if y <= targetY then
            return t_below, t
        end
    end
    return -1, -1
end

-- UPGRADED: Now accepts the tier parameter to adjust base velocity
local function findBestPitch(dist, targetY, cY, charges, length, tier)
    -- Calculate speed based on Mk. level (Base=2.0, Mk1=2.5, Mk2=3.0, etc.)
    local speedPerCharge = 2.0 + (tier * 0.5)
    local initSpeed = (charges * speedPerCharge) + (length * VELOCITY_PER_BARREL)
    
    local bestDiff = 999999
    local bestPitch = nil
    local bestAirtime = 0
    
    local search = function(startP, endP, step)
        local bDiff, bPitch, bTime = bestDiff, bestPitch, bestAirtime
        for p = startP, endP, step do
            local rad = math.rad(p)
            local Vw = math.cos(rad) * initSpeed
            local Vy = math.sin(rad) * initSpeed
            
            local xBarrel = length * math.cos(rad)
            local distToCover = dist - xBarrel
            
            local dragFactor = distToCover / (100 * Vw)
            if dragFactor < 1 and dragFactor > -1 then 
                local t_horiz = math.abs(math.log(1 - dragFactor) / -0.010050335853501)
                local yBarrel = cY + math.sin(rad) * length
                
                local t_below, t_above = timeInAir(yBarrel, targetY, Vy)
                
                if t_below >= 0 then
                    local diff1 = math.abs(t_horiz - t_below)
                    local diff2 = math.abs(t_horiz - t_above)
                    local minDiff = math.min(diff1, diff2)
                    
                    if minDiff < bDiff then
                        bDiff = minDiff
                        bPitch = p
                        bTime = t_horiz
                    end
                end
            end
        end
        return bDiff, bPitch, bTime
    end
    
    local d, p, t = search(-30, 60, 1)
    if p then
        d, p, t = search(p - 2, p + 2, 0.05)
        return p, t, d
    end
    return nil, nil, nil
end

term.clear()
term.setCursorPos(1,1)
print("== POCKET ICBM UPLINK ==")
print("Searching for Firebase...")

rednet.broadcast({cmd = "GET_INFO"}, "CBC_ARTILLERY")
local serverId, info = rednet.receive("CBC_ARTILLERY", 3)

if not serverId then
    print("ERROR: No Cannon Server found.")
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

print("Number of Charges:")
local charges = tonumber(io.read())

-- NEW: Ask for the Enhanced Shell Tier
print("Charge Tier (0=Base, 1-5=Mk1-5):")
local chargeTier = tonumber(io.read()) or 0

-- ==========================================
-- 3. CBC BALLISTIC SIMULATION
-- ==========================================
local dx = tX - cX
local dz = tZ - cZ
local distXZ = math.sqrt(dx^2 + dz^2)

term.clear()
term.setCursorPos(1,1)
print("Simulating Trajectory...")

-- Pass the new chargeTier into the simulator
local targetPitch, airtimeTicks, accuracyDiff = findBestPitch(distXZ, tY, cY, charges, BARREL_LENGTH, chargeTier)

if not targetPitch then
    print("== SOLUTION FAILED ==")
    print("OUT OF RANGE! Target too far.")
    return
end

local targetYaw = math.deg(math.atan2(-dx, dz)) + YAW_OFFSET
targetYaw = (targetYaw % 360 + 360) % 360
airtimeTicks = math.floor(airtimeTicks)

-- ==========================================
-- 4. REMOTE EXECUTION
-- ==========================================
term.clear()
term.setCursorPos(1,1)
print("Tgt : " .. math.floor(distXZ) .. "m away")
print("Yaw : " .. string.format("%.1f", targetYaw))
print("Ptch: " .. string.format("%.2f", targetPitch))
print("Fuze: " .. airtimeTicks .. " ticks")

print("\n[C] Cancel, [Enter] Assemble")
if io.read() == "c" then return end

rednet.send(serverId, {cmd = "ASSEMBLE", state = true}, "CBC_ARTILLERY")
rednet.receive("CBC_ARTILLERY", 1) 

print("Sending Aim Data...")
rednet.send(serverId, {cmd = "AIM", yaw = targetYaw, pitch = targetPitch}, "CBC_ARTILLERY")

while true do
    rednet.send(serverId, {cmd = "GET_INFO"}, "CBC_ARTILLERY")
    local _, curInfo = rednet.receive("CBC_ARTILLERY", 2)
    
    if curInfo and curInfo.yaw then
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
