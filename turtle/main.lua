local websocketUrl = "ws://localhost:2828"
local reconnectInterval = 5

local debugMode = false -- Set to true for debugging, false for normal execution

local osName = "Project Bore OS"
local version = "v1.0.0"
function term.reset()
    term.clear()
    term.setCursorPos(1, 1)
end

local function printHeader()
    term.reset()
    print(osName .. (debugMode and " (debug)" or ""))
    print(version)
    print("\n~~~~~~~~~")
end

local function printConnecting()
    printHeader()
    print("\nConnecting to " .. websocketUrl .. '\n')
end

local function printReconnecting()
    print("\nConnection lost.")
    print("Connecting to " .. websocketUrl .. '\n')
end

local direction = nil
local dirs = {"north", "east", "south", "west"}
local function calibrate()
    local attempts = 0

    local x1, _, z1 = gps.locate()
    local success = false
    for _ = 0, 4 do
        if not success then
            turtle.turnLeft()
            success = turtle.forward()
        end
    end
    local x2, _, z2 = gps.locate()

    local xdiff = x2 - x1
    local zdiff = z2 - z1

    if zdiff == -1 then
        return 1
    elseif zdiff == 1 then
        return 3
    elseif xdiff == 1 then
        return 2
    elseif xdiff == -1 then
        return 4
    else
        print("Failed to move...")
        attempts = attempts + 1

        if attempts <= 3 then
            if not turtle.inspectUp() then
                turtle.up()
                return calibrate() -- Dangerous nesting, but its limited via attempts
            end
        else
            print("Unable to calibrate (obstructed)")
        end
    end
end

function turtle.left()
    turtle.turnLeft()
    direction = (direction - 1) % 3
end

function turtle.right()
    turtle.turnRight()
    direction = (direction + 1) % 3
end

local function connect()
    while true do
        printConnecting()
        local ws, err = http.websocket(websocketUrl)
        if ws then
            direction = calibrate()
            turtle.back()

            local x, y, z = gps.locate()
            print("Position: " .. x .. ", " .. y .. ", " .. z .. " -> " ..
                      dirs[direction])

            function ws.transmit(dataType, data)
                local message = textutils.serializeJSON({
                    type = dataType,
                    data = data
                })
                ws.send(message)

            end

            return ws
        else
            print("\nConnection failed: " .. err)
            print("Reconnecting in " .. reconnectInterval .. " seconds...")
            sleep(reconnectInterval)
        end
    end
end

local function sendPosition(ws)
    local x, y, z = gps.locate() -- Or use turtle.getBlockPosition()
    if x then
        ws.transmit("pos", {x = x, y = y, z = z, direction})
    else
        print("\nGPS not available")
    end
end

local function sendWorldState(ws)
    local x, y, z = gps.locate()
    local blocks = {}

    -- Check block in front of the turtle
    local success, blockInfo = turtle.inspect()
    if success then
        local blockData = {
            id = blockInfo.name,
            pos = {x = x, y = y, z = z + 1} -- Assuming turtle is facing towards positive z
        }
        table.insert(blocks, blockData)
    end

    -- Check block above the turtle
    success, blockInfo = turtle.inspectUp()
    if success then
        local blockData = {id = blockInfo.name, pos = {x = x, y = y + 1, z = z}}
        table.insert(blocks, blockData)
    end

    -- Check block below the turtle
    success, blockInfo = turtle.inspectDown()
    if success then
        local blockData = {id = blockInfo.name, pos = {x = x, y = y - 1, z = z}}
        table.insert(blocks, blockData)
    end

    -- Transmit the collected block data
    ws.transmit("world", {blocks = blocks})
end

local function handleMessages(ws)
    while true do
        local event, url, message = os.pullEvent("websocket_message")
        if event == "websocket_message" and url == websocketUrl then
            local ok, data = pcall(textutils.unserializeJSON, message)
            if ok then
                if data.type == "exec" then
                    if debugMode then
                        print("\n" .. data.data)
                    else
                        local status, err = pcall(load(data.data))
                        if not status then
                            print("Failed to execute command: " .. data.data ..
                                      "\n" .. err)
                        end
                    end
                elseif data.type == "print" then
                    print(data.data)
                end

                sendPosition(ws)
                sendWorldState(ws)
            else
                print("Failed to parse JSON: " .. data)
            end
        end
    end
end

local function handleClose()
    while true do
        local event, url, reason = os.pullEvent("websocket_closed")
        if event == "websocket_closed" and url == websocketUrl then
            print("\nWebSocket closed: " .. reason)
            printReconnecting()
            return
        end
    end
end

local function main()
    turtle.select(1)
    turtle.equipLeft() -- Unequip item to see if we have it
    while not turtle.getItemDetail(1) or
        not (turtle.getItemDetail(1).name ==
            "computercraft:wireless_modem_advanced") do
        term.reset()
        print("Waiting for ender modem...")
        os.sleep(0.5)
    end
    turtle.equipLeft()
    print("Received ender modem!")

    while not gps.locate() do
        term.reset()
        print("Waiting for gps setup...")
        os.sleep(0.5)
    end
    print("Recieved gps signal!")

    while not (turtle.getItemCount(1) >= 8) do
        term.reset()
        print("Waiting for fuel (min 8)...")
        os.sleep(0.5)
    end
    print("Recieved fuel (" .. turtle.getFuelLevel() .. " blocks)!")
    turtle.refuel()

    print("\nAwaiting confirmation (press any key to continue)...")
    while not os.pullEvent("key") do os.sleep(0.25) end

    while true do
        local ws = connect()
        parallel.waitForAny(function() handleMessages(ws) end, handleClose)
    end
end

printHeader()
main()
