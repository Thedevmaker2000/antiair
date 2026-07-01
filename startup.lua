-- ==========================================
-- CBC ARTILLERY SERVER (CANNON SIDE) v15
-- (Auto-Disassembly & Reloader Integration)
-- ==========================================

-- 1. Initialize Hardware
local cannon = peripheral.find("cannon_mount")
if not cannon then
    print("FATAL: Cannon mount not found.")
    return
end

peripheral.find("modem", function(name) rednet.open(name) end)
cannon.setComputerControl(true)

-- ==========================================
-- HARDWARE CONFIGURATION
-- ==========================================
-- Which side is your Auto-Reloader Redstone Link attached to?
-- Options: "top", "bottom", "left", "right", "front", "back"
local RELOAD_SIDE = "bottom" 

-- ==========================================

term.clear()
term.setCursorPos(1,1)
print("=== CBC FIREBASE SERVER ===")
print("Server ID : " .. os.getComputerID())
print("Status    : ONLINE & LISTENING")
print("Reloader  : Linked to '" .. RELOAD_SIDE .. "'")
print("---------------------------")

-- 2. The Command Loop
while true do
    local senderId, msg, protocol = rednet.receive("CBC_ARTILLERY")
    
    if type(msg) == "table" then
        if msg.cmd == "GET_INFO" then
            rednet.send(senderId, cannon.getInfo(), "CBC_ARTILLERY")
            
        elseif msg.cmd == "ASSEMBLE" then
            local result = cannon.assemble(msg.state)
            rednet.send(senderId, {success = result}, "CBC_ARTILLERY")
            
        elseif msg.cmd == "AIM" then
            cannon.setTargetAngles(msg.yaw, msg.pitch)
            print("> Aiming to Yaw: " .. math.floor(msg.yaw) .. ", Pitch: " .. math.floor(msg.pitch))
            
        elseif msg.cmd == "FIRE" then
            print("> Executing Firing Sequence...")
            
            -- 1. FIRE (Held for 1 full second to bypass server lag)
            cannon.fire(true)
            os.sleep(1.0) 
            cannon.fire(false)
            if msg.state then print("> SHOT OUT!") end
            
            -- 2. DISASSEMBLE
            -- Wait for recoil/firing animation to finish before disassembling
            os.sleep(1.0) 
            print("> Disassembling Cannon...")
            cannon.assemble(false)
            
            -- 3. AUTO-RELOAD
            -- Wait half a second for the blocks to become entities again
            os.sleep(0.5)
            print("> Triggering Mechanical Reloader...")
            
            -- Send a clean 0.5-second redstone pulse to your Redstone Link
            redstone.setOutput(RELOAD_SIDE, true)
            os.sleep(0.5) 
            redstone.setOutput(RELOAD_SIDE, false)
            
            print("> Ready for next mission.")
            print("---------------------------")
        end
    end
end
