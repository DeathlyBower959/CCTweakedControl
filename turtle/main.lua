local websocketUrl = "ws://localhost:2828"
local reconnectInterval = 5

local debugMode = true -- Set to true for debugging, false for normal execution

local osName = "Project Bore OS"
local version = "v1.0.0"
local function clearScreen()
    term.clear()
    term.setCursorPos(1, 1)
end

local function printHeader()
    clearScreen()
    print(osName .. (debugMode and " (debug)" or ""))
    print(version)
    print("~~~~~~~~~")
end

local function printConnecting()
    printHeader()
    print("\nConnecting to " .. websocketUrl)
end

local function printReconnecting()
    print("\nConnection lost.")
    print("Connecting to " .. websocketUrl)
end

local function connect()
    while true do
        printConnecting()
        local ws, err = http.websocket(websocketUrl)
        if ws then
            return ws
        else
            print("\nConnection failed: " .. err)
            print("Reconnecting in " .. reconnectInterval .. " seconds...")
            sleep(reconnectInterval)
        end
    end
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

local function sendPosition(ws)
    local x, y, z = gps.locate() -- Or use turtle.getBlockPosition()
    if x then
        ws.transmit("pos", {x = x, y = y, z = z})
    else
        print("\nGPS not available")
    end
end

local function main()
    while true do
        local ws = connect()
        parallel.waitForAny(function() handleMessages(ws) end, handleClose)
    end
end

-- Clear the terminal and print header
printHeader()

-- Start the main loop
main()
