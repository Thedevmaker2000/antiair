-- Isolate the very first relay (Yaw Positive / Left)
local relay = peripheral.wrap("redstone_relay_0")

if not relay then
    print("HARDWARE FAIL: Computer cannot see 'redstone_relay_0'.")
    print("Check your networking cables and ensure the Wired Modem on the relay has a RED RING.")
    return
end

print("Hardware connected! Sending power override...")

-- Try to turn it on, and catch any API errors
local success, err = pcall(function()
    relay.setOutput("top", true)
    relay.setOutput("bottom", true)
    relay.setOutput("left", true)
    relay.setOutput("right", true)
    relay.setOutput("front", true)
    relay.setOutput("back", true)
end)

if not success then
    print("SOFTWARE FAIL: The relay does not accept 'setOutput'.")
    print("Error details: " .. tostring(err))
else
    print("SUCCESS! The relay should physically be glowing right now.")
    print("Press any key to turn it off...")
    os.pullEvent("key")
    
    -- Turn it back off
    relay.setOutput("top", false)
    relay.setOutput("bottom", false)
    relay.setOutput("left", false)
    relay.setOutput("right", false)
    relay.setOutput("front", false)
    relay.setOutput("back", false)
    print("Relay deactivated.")
end
