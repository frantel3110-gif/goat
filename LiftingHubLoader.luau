-- Diagnostic loader: the status box appears BEFORE any web request.
local player = game:GetService("Players").LocalPlayer
assert(player, "Join the game before executing")
local parent = player:WaitForChild("PlayerGui", 10)
assert(parent, "PlayerGui unavailable")
local old = parent:FindFirstChild("LiftingLoaderStatus")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "LiftingLoaderStatus"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 2000000000
gui.Parent = parent
if type(gethui) == "function" then pcall(function()
    local container = gethui()
    if typeof(container) == "Instance" then
        local previous = container:FindFirstChild(gui.Name)
        if previous and previous ~= gui then previous:Destroy() end
        gui.Parent = container
    end
end) end
local box = Instance.new("TextLabel")
box.Size = UDim2.new(0.9, 0, 0, 150)
box.Position = UDim2.new(0.05, 0, 0.06, 0)
box.BackgroundColor3 = Color3.fromRGB(20, 26, 38)
box.BackgroundTransparency = 0
box.BorderSizePixel = 0
box.TextColor3 = Color3.new(1, 1, 1)
box.TextSize = 18
box.Font = Enum.Font.SourceSans
box.TextWrapped = true
box.Text = "1/4: Lua started. Preparing download..."
box.Parent = gui
local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(34, 26)
close.Position = UDim2.new(1, -36, 0, 2)
close.Text = "X"
close.Parent = box
close.Activated:Connect(function() gui:Destroy() end)
local complete = false
task.delay(15, function()
    if not complete and gui.Parent then
        box.Text = box.Text .. "\nStill waiting after 15 seconds. Note the stage above."
    end
end)
task.wait(0.2)
local good, problem = pcall(function()
    box.Text = "2/4: Downloading the menu from GitHub..."
    local url = "https://raw.githubusercontent.com/frantel3110-gif/goat/refs/heads/main/LiftingHubFixed.luau"
    local source = game:HttpGet(url .. "?v=" .. tostring(os.time()))
    assert(type(source) == "string" and #source > 100, "GitHub returned an empty or short response")
    box.Text = "3/4: Downloaded " .. #source .. " bytes. Compiling..."
    assert(type(loadstring) == "function", "loadstring is unavailable in this execution environment")
    local chunk, compileError = loadstring(source, "LiftingHubFixed")
    assert(chunk, "Compile error: " .. tostring(compileError))
    box.Text = "4/4: Starting the menu..."
    local initialized, detail = chunk()
    assert(initialized ~= false, "Menu startup: " .. tostring(detail))
end)
complete = true
if not good then
    box.Text = "LOADER ERROR:\n" .. tostring(problem)
    warn("[Lifting loader] " .. tostring(problem))
else
    box.Text = "Menu startup completed. Close this box with X.\nIf the menu is hidden, press Insert."
end
