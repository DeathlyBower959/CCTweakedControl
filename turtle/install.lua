-- On floppy disk
local pastebinID = "AhKtxL4t"
local filename = "startup/main.lua"

local url = "https://pastebin.com/raw/" .. pastebinID
local response = http.get(url)
if response then
    local content = response.readAll()
    response.close()

    shell.run('rm ' .. filename)
    local file = fs.open(filename, "w")
    file.write(content)
    file.close()

    shell.run(filename)
else
    print("Failed to download from Pastebin.")
end

-- TODO: Fix to make hatching not install from pastebin, but a local file
