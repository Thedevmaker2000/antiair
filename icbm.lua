-- ==========================================
-- REMOTE ARTILLERY CLIENT (POCKET PC) v16
-- (CBC Tick-Simulation Ballistics)
-- Original Python Math by @sashafiesta#1978
-- ==========================================

peripheral.find("modem", function(name) rednet.open(name) end)

-- ==========================================
-- 1. CALIBRATION
-- ==========================================
local BARREL_LENGTH = 10 
local YAW_OFFSET = 0

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

local function findBestPitch(dist, targetY, cY, charges, length)
    local initSpeed = charges * 2.0
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
            -- Only calculate if the target is horizontally reachable against drag
            if dragFactor < 1 and dragFactor > -1 then 
                local t_horiz = math.abs(math.log(1 - dragFactor) / -0.010050335853501)
                local yBarrel = cY + math.sin(rad) * length
                
                local t_below, t_above = timeInAir(yBarrel, targetY, Vy)
                
                if t_below >= 0 then
                    local diff1 = math.abs(t_horiz - t_below)
                    local diff2 = math.abs(t_horiz - t_above)
                    local minDiff = math.min(diff1, diff2)
                    local timeToUse = (minDiff == diff1) and t_below or t_above
                    
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
    
    -- Pass 1: Fast coarse search (-30 to 60 deg)
    local d, p, t = search(-30, 60, 1)
    if p then
        -- Pass 2: Fine search for ultimate precision
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
-- 2. COORDS
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
-- 3. CBC BALLISTIC SIMULATION
-- ==========================================
local dx = tX - cX
local dz = tZ - cZ
local distXZ = math.sqrt(dx^2 + dz^2)

term.clear()
term.setCursorPos(1,1)
print("Simulating Trajectory...")

local targetPitch, airtimeTicks, accuracyDiff = findBestPitch(distXZ, tY, cY, charges, BARREL_LENGTH)

if not targetPitch then
    print("== SOLUTION FAILED ==")
    print("OUT OF RANGE! (Target too far for " .. charges .. " charges against air resistance)")
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
rednet.receive("CBC_ARTILLERY", 1) -- Clear inbox

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
