local scanner = peripheral.find("environmentDetector")

print("Executing raw scan at 32m...")
local success, result = pcall(scanner.scanEntities, 32)

if not success then
    print("API ERROR: " .. tostring(result))
elseif type(result) == "table" then
    print("SUCCESS! The scanner sees " .. #result .. " entities.")
    for i, ent in ipairs(result) do
        print("- " .. tostring(ent.name) .. " (X:" .. math.floor(ent.x) .. ", Y:" .. math.floor(ent.y) .. ")")
        if i >= 10 then 
            print("...and more.")
            break 
        end
    end
else
    print("WEIRD RESULT: " .. tostring(result))
end
