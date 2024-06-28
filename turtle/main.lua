-- Why do i need to do this???
http = http
turtle = turtle
term = term
gps = gps
textutils = textutils
shell = shell
parallel = parallel
peripheral = peripheral
os.sleep = os.sleep
os.pullEvent = os.pullEvent
os.getComputerID = os.getComputerID
-- 

local websocket_url = "ws://localhost:2828"
local reconnect_interval = 5

local os_name = "Project Bore OS"
local version = "v1.0.0"
function term.reset()
    term.clear()
    term.setCursorPos(1, 1)
end

local function printHeader()
    term.reset()
    print(os_name)
    print(version)
    print("\n~~~~~~~~~")
end

-- Turtle State/Position
local direction = nil
local directions = {"north", "east", "south", "west"}

local function getDirection(x1, z1, x2, z2)

    local xdiff = x2 - x1
    local zdiff = z2 - z1

    if xdiff and zdiff then
        return
            (zdiff == -1 and 1) or (zdiff == 1 and 3) or (xdiff == 1 and 2) or
                (xdiff == -1 and 4)
    end

    print("Unable to get direction (obstructed)")
    return nil

end

local function calibrate()
    local x1, _, z1 = gps.position()
    for _ = 0, 4 do if turtle.inspect() then turtle.turnLeft() end end
    local success = turtle.forward()

    local x2, _, z2 = gps.position()
    if success then turtle.back() end

    return getDirection(x1, z1, x2, z2)

end

-- Extension Functions
function turtle.left()
    turtle.turnLeft()
    direction = (direction - 1) % 3
end

function turtle.right()
    turtle.turnRight()
    direction = (direction + 1) % 3
end

function turtle.move()
    getFuelStatus()
    return turtle.forward()
end
function turtle.reverse()
    getFuelStatus()
    return turtle.back()
end
function turtle.rise()
    getFuelStatus()
    return turtle.up()
end
function turtle.descend()
    getFuelStatus()
    return turtle.down()
end

function turtle.getItemIndex(name)
    for slot = 1, 16, 1 do
        local item = turtle.getItemDetail(slot)
        if item and item["name"] == name then return slot end
    end
end
function turtle.getInventory()
    local inventory = {}
    for x = 1, 4, 1 do
        for y = 1, 4, 1 do
            local slot = 4 * (y - 1) + x
            local item = turtle.getItemDetail(slot)
            local remaining = turtle.getItemSpace(slot)

            table.insert(inventory, {item = item, remaining = remaining})
        end
    end

    return inventory
end

function turtle.hatch()
    local turtle_idx = turtle.getItemIndex("computercraft:turtle_normal")
    local disk_drive_idx = turtle.getItemIndex("computercraft:disk_drive")
    local floppy_disk_idx = turtle.getItemIndex("computercraft:disk")
    local ender_modem_idx = turtle.getItemIndex(
                                "computercraft:wireless_modem_advanced")
    local fuel_idx = turtle.getItemIndex("minecraft:coal") or
                         turtle.getItemIndex("minecraft:coal_block")
    local diamond_pickaxe_idx = turtle.getItemIndex("minecraft:diamond_pickaxe")

    local hatch_ready = true
    if not turtle_idx then
        print("Missing turtle!")
        hatch_ready = false
    end
    if not disk_drive_idx then
        print("Missing disk drive!")
        hatch_ready = false
    end
    if not floppy_disk_idx then
        print("Missing floppy disk!")
        hatch_ready = false
    end
    if not ender_modem_idx then
        print("Missing ender modem!")
        hatch_ready = false
    end
    if not diamond_pickaxe_idx then
        print("Missing diamond pickaxe!")
        hatch_ready = false
    end
    if not fuel_idx or turtle.getItemCount(fuel_idx) < 12 then
        print("Missing reserve fuel (>12)!")
        hatch_ready = false
    end
    if not hatch_ready then return end

    turtle.dig()
    turtle.select(disk_drive_idx)
    turtle.place()

    turtle.select(floppy_disk_idx)
    turtle.drop(1)

    turtle.rise()
    turtle.dig()
    turtle.select(turtle_idx)
    turtle.place()

    turtle.select(ender_modem_idx)
    turtle.drop(1)

    turtle.select(fuel_idx)
    turtle.drop(8)

    turtle.select(diamond_pickaxe_idx)
    turtle.drop()

    peripheral.call("front", "turnOn")
    peripheral.call("front", "reboot")

    turtle.digDown()
    turtle.descend()
    turtle.suck()
    turtle.dig()
end

function gps.position()
    local x, y, z

    while not (x or y or z) do
        x, y, z = gps.locate()
        if not (x or y or z) then print("\nGPS not available") end
    end
    return x, y, z, direction
end

-- Turtle Information
local function getLookingState(x, y, z, dir)
    -- Check block in front of the turtle
    local success, block_info = turtle.inspect()
    if success then
        local blockData = {
            id = block_info.name,
            pos = {x = x - ((dir - 3) % 2), y = y, z = z + ((dir - 2) % 2)} -- Calculate using opposite directions, and offsetting the cardinal directions to negative
        }
        return blockData
    end
end
local function getWorldState(full_scan)
    local x, y, z, dir = gps.position()

    local blocks = {}
    for _ = 1, full_scan and 4 or 1, 1 do
        local block_data = getLookingState(x, y, z, dir)
        table.insert(blocks, block_data)
        if full_scan then turtle.left() end
    end

    -- Check block above the turtle
    local success, block_info = turtle.inspectUp()
    if success then
        local block_data = {
            id = block_info.name,
            pos = {x = x, y = y + 1, z = z}
        }
        table.insert(blocks, block_data)
    end

    -- Check block below the turtle
    success, block_info = turtle.inspectDown()
    if success then
        local block_data = {
            id = block_info.name,
            pos = {x = x, y = y - 1, z = z}
        }
        table.insert(blocks, block_data)
    end

    -- Return the collected block data
    return #blocks > 0 and blocks or nil
end
function getFuelStatus()
    local fuel = turtle.getFuelLevel()
    if fuel < 80 then
        turtle.ws.transmit({
            type = "fuel",
            data = {remaining = fuel, capacity = turtle.getFuelLimit()}
        })
    end
end

-- Websocket
local function connect()
    direction = nil
    while true do
        printHeader()
        print("\nCalibrating...")
        while not direction do
            direction = calibrate()
            os.sleep(1)
        end

        local x, y, z, dir = gps.position()
        printHeader()
        print("Position: " .. x .. ", " .. y .. ", " .. z .. " -> " ..
                  directions[dir])

        print("\nConnecting to " .. websocket_url)
        local ws, err = http.websocket(websocket_url)
        if ws then
            print("Connected!\n")
            function ws.transmit(type, data)
                local message = textutils.serializeJSON({
                    type = type,
                    data = data
                })

                success = pcall(ws.send, message)
                if not success then
                    print("Failed to transmit: " .. type .. " - " ..
                              tostring(data))
                    return
                end
            end

            function ws.bulk_transmit(items)
                for _, value in ipairs(items) do
                    ws.transmit(value.type, value.data)
                end
            end

            turtle.ws = ws
            -- sendData(ws, true)

            return ws
        else
            print("\nConnection failed: " .. err)
            print("Reconnecting in " .. reconnect_interval .. " seconds...")
            os.sleep(reconnect_interval)
        end
    end
end

local function handleMessages(ws)
    while true do
        local success, message = pcall(ws.receive)
        if not success then return end
        if message then
            local ok, data = pcall(textutils.unserializeJSON, message)
            if ok then
                if data.type == "exec" then
                    local status, err = pcall(load(data.data) or error)
                    if not status then
                        print(
                            "Failed to execute command: " .. data.data .. "\n" ..
                                err)
                    end
                elseif data.type == "print" then
                    print(data.data)
                end

                sendData(ws)
            else
                print("Failed to parse JSON: " .. data)
            end
        end
    end
end

local function handleClose()
    while true do
        local event, url, reason = os.pullEvent("websocket_closed")
        if event == "websocket_closed" and url == websocket_url then
            print("\nWebSocket closed: " .. reason)
            return
        end
    end
end

function sendData(ws, full_scan)
    local x, y, z, dir = gps.position()
    local blocks = getWorldState(full_scan)
    ws.bulk_transmit({
        {type = "pos", data = {x = x, y = y, z = z, direction = dir}},
        blocks and {type = "world", data = blocks} -- Needed as if the turtle is fully surrounded by air, lua converts the table into a js object :(
    })
end

-- MAIN
printHeader()

turtle.select(16)
turtle.dropUp()
turtle.equipLeft() -- Unequip item to see if we have it
while not turtle.getItemIndex("computercraft:wireless_modem_advanced") do
    term.reset()
    print("Waiting for ender modem...")
    os.sleep(0.5)
end
turtle.select(turtle.getItemIndex("computercraft:wireless_modem_advanced"))
turtle.equipLeft()
turtle.suckUp()
print("Received ender modem!")

turtle.select(15)
turtle.dropUp()
turtle.equipRight() -- Unequip item to see if we have it
while not turtle.getItemIndex("minecraft:diamond_pickaxe") do
    term.reset()
    print("Waiting for diamond pickaxe...")
    os.sleep(0.5)
end
turtle.select(turtle.getItemIndex("minecraft:diamond_pickaxe"))
turtle.equipRight()
turtle.suckUp()
print("Received pickaxe!")

while not gps.locate() do
    term.reset()
    print("Waiting for gps setup...")
    os.sleep(0.5)
end
print("Recieved gps signal!")

while not (turtle.getFuelLevel() >= 640) do
    term.reset()
    print("Waiting for fuel (min 640 blocks)...")
    for i = 1, 16, 1 do
        local item = turtle.getItemDetail(i)
        if item then
            if item.name == "minecraft:coal" or item.name ==
                "minecraft:coal_block" then
                turtle.select(i)
                turtle.refuel(32) -- Will max refuel 32 incase of hatching
            end
        end
    end
    os.sleep(0.5)
end
print("Recieved fuel (" .. turtle.getFuelLevel() .. " blocks)!")

while true do
    local ws = connect()
    if ws then
        pcall(ws.transmit, "ready", {id = os.getComputerID()})
        parallel.waitForAny(function() handleMessages(ws) end, handleClose)
    end
end
