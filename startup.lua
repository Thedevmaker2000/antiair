-- ==========================================
-- CBC ARTILLERY SERVER (CANNON SIDE)
-- Put this on the computer attached to the cannon.
-- ==========================================

-- 1. Initialize Hardware
local cannon = peripheral.find("cannon_mount")
if not cannon then
    print("FATAL: Cannon mount not found.")
    return
end

-- Open all attached modems automatically
peripheral.find("modem", function(name) rednet.open(name) end)

cannon.setComputerControl(true)

term.clear()
term.setCursorPos(1,1)
print("=== CBC FIREBASE SERVER ===")
print("Server ID : " .. os.getComputerID())
print("Status    : ONLINE & LISTENING")
print("Protocol  : CBC_ARTILLERY")
print("---------------------------")

-- 2. The Command Loop
while true do
    -- Listen for messages on our specific protocol
    local senderId, msg, protocol = rednet.receive("CBC_ARTILLERY")
    
    if type(msg) == "table" then
        if msg.cmd == "GET_INFO" then
            -- Send back telemetry
            rednet.send(senderId, cannon.getInfo(), "CBC_ARTILLERY")
            
        elseif msg.cmd == "ASSEMBLE" then
            -- Assemble and reply with success/fail
            local result = cannon.assemble(msg.state)
            rednet.send(senderId, {success = result}, "CBC_ARTILLERY")
            
        elseif msg.cmd == "AIM" then
            -- Tell the API to move the motors
            cannon.setTargetAngles(msg.yaw, msg.pitch)
            print("> Aiming to Yaw: " .. math.floor(msg.yaw) .. ", Pitch: " .. math.floor(msg.pitch))
            
        elseif msg.cmd == "FIRE" then
            -- Pull the trigger
            cannon.fire(msg.state)
            if msg.state then print("> SHOT OUT!") end
        end
    end
end
