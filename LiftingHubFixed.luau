-- Paste the ENTIRE file. No HTTP loader or external UI library is needed.
local bootOK, bootError = xpcall(function()
    local Players = game:GetService("Players")
    local RS = game:GetService("ReplicatedStorage")
    local Input = game:GetService("UserInputService")
    local player = Players.LocalPlayer
    assert(player, "Join the game before executing")
    local parent = player:WaitForChild("PlayerGui", 10)
    assert(parent, "PlayerGui did not load")
    local env = _G
    if type(getgenv) == "function" then
        local good, result = pcall(getgenv)
        if good and type(result) == "table" then env = result end
    end
    if type(env.LiftingHub) == "table" and type(env.LiftingHub.stop) == "function" then
        pcall(env.LiftingHub.stop)
    end
    pcall(function() _G.AutoLiftToken = nil end)
    for _, name in ipairs({"LiftingHubFixed", "WeightLiftTestMenu"}) do
        local old = parent:FindFirstChild(name)
        if old then old:Destroy() end
    end
    local s = {alive = true, lift = false, sell = false, buy = false, afk = false,
        skill = false, rate = 15, interval = 30, sent = 0, visits = 0}
    local connections, paints = {}, {}
    local controller, catalog, remote, spot, visit, pending
    local shadow, targets, selected = {}, {}, 1
    local targetIndex, nextSell, lastSkill = 48, 0, -math.huge
    local baseline, lastCash, increases = nil, nil, 0
    local loading, checking = false, false
    local gui, panel, reopen, message
    local manager = {}
    env.LiftingHub = manager
    local function make(kind, props, container)
        local object = Instance.new(kind)
        for key, value in pairs(props) do object[key] = value end
        object.Parent = container
        return object
    end
    gui = make("ScreenGui", {Name = "LiftingHubFixed", ResetOnSpawn = false,
        DisplayOrder = 100000, IgnoreGuiInset = true}, parent)
    -- Prefer an executor-provided UI container when available; keep PlayerGui as the fallback.
    if type(gethui) == "function" then pcall(function()
        local container = gethui()
        if typeof(container) == "Instance" then
            local previous = container:FindFirstChild("LiftingHubFixed")
            if previous and previous ~= gui then previous:Destroy() end
            gui.Parent = container
        end
    end) end
    panel = make("Frame", {Size = UDim2.new(0.92, 0, 0.86, 0),
        Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(18, 24, 36), BackgroundTransparency = 0,
        BorderSizePixel = 0}, gui)
    make("UISizeConstraint", {MaxSize = Vector2.new(580, 680)}, panel)
    make("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
    local function label(container, text, height)
        return make("TextLabel", {Size = UDim2.new(1, 0, 0, height or 54),
            BackgroundTransparency = 1, Text = text, TextSize = 14,
            Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(230, 238, 250),
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top}, container)
    end
    local title = label(panel, "  LIFTING HUB  |  drag here", 40)
    title.Active = true
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Size = UDim2.new(1, -90, 0, 40)
    message = label(panel, "Menu loaded. All automation is OFF.", 70)
    message.Name = "HubStatus"
    message.Position = UDim2.new(0, 12, 1, -78)
    message.Size = UDim2.new(1, -24, 0, 70)
    local function say(text)
        if not s.alive then return end
        message.Text = tostring(text)
        print("[Lifting Hub] " .. tostring(text))
    end
    local function safe(callback)
        return function(...)
            if not s.alive then return end
            local good, problem = pcall(callback, ...)
            if not good then say("Error: " .. tostring(problem)) end
        end
    end
    local function connect(signal, callback)
        table.insert(connections, signal:Connect(safe(callback)))
    end
    local function button(container, text, callback)
        local b = make("TextButton", {Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.fromRGB(39, 54, 78), BackgroundTransparency = 0,
            BorderSizePixel = 0, Text = text, TextSize = 14, TextWrapped = true,
            Font = Enum.Font.GothamMedium, TextColor3 = Color3.new(1, 1, 1)}, container)
        make("UICorner", {CornerRadius = UDim.new(0, 6)}, b)
        connect(b.Activated, function() task.spawn(safe(callback)) end)
        return b
    end
    local hide = button(panel, "Hide", function() panel.Visible = false; reopen.Visible = true end)
    hide.Position, hide.Size = UDim2.new(1, -78, 0, 5), UDim2.fromOffset(68, 30)
    reopen = button(gui, "OPEN HUB", function() panel.Visible = true; reopen.Visible = false end)
    reopen.Position, reopen.Size, reopen.Visible = UDim2.fromOffset(12, 60), UDim2.fromOffset(115, 38), false
    local bar = make("Frame", {Position = UDim2.fromOffset(12, 44),
        Size = UDim2.new(1, -24, 0, 32), BackgroundTransparency = 1}, panel)
    make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6)}, bar)
    local pages = {}
    local function page(name)
        local body = make("ScrollingFrame", {Position = UDim2.fromOffset(12, 84),
            Size = UDim2.new(1, -24, 1, -174), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = #pages == 0}, panel)
        make("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, body)
        local tab = button(bar, name, function()
            for _, other in ipairs(pages) do other.Visible = other == body end
        end)
        tab.Size = UDim2.new(1 / 3, -4, 1, 0)
        table.insert(pages, body)
        return body
    end
    local farm, shop, tests = page("Farm"), page("Shop"), page("Skills / checks")
    local function repaint() for _, paint in pairs(paints) do paint() end end
    local function toggle(container, caption, key, changed)
        local b
        b = button(container, "", function()
            s[key] = not s[key]
            if changed then changed(s[key]) end
            repaint()
        end)
        paints[key] = function()
            b.Text = caption .. (s[key] and ": ON" or ": OFF")
            b.BackgroundColor3 = s[key] and Color3.fromRGB(21, 112, 85) or Color3.fromRGB(39, 54, 78)
        end
        paints[key]()
    end
    local function data()
        return controller and type(controller.PlayerData) == "table" and controller.PlayerData or shadow
    end
    local function actor()
        local model = player.Character
        return model, model and model:FindFirstChildOfClass("Humanoid"), model and model:FindFirstChild("HumanoidRootPart")
    end
    local function num(value)
        local n = tonumber(value)
        if n and n == n and n >= 0 and n < math.huge then return n end
    end
    local function fmt(value)
        local n = tonumber(value)
        if not n then return "waiting" end
        for _, u in ipairs({{1e12, "T"}, {1e9, "B"}, {1e6, "M"}, {1e3, "K"}}) do
            if math.abs(n) >= u[1] and math.abs(n) < u[1] * 1000 then return ("%.3f%s"):format(n / u[1], u[2]) end
        end
        return ("%.6g"):format(n)
    end
    local function send(packet)
        assert(remote, "RemoteEvent not ready. Press Reload game data.")
        remote:FireServer(packet)
    end
    local function returnHome()
        local current = visit
        visit = nil
        local model, h, root = actor()
        if current and model == current.model and root == current.root and h and h.Health > 0 then
            root.CFrame = current.origin
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
    local function stopAll()
        for _, key in ipairs({"lift", "sell", "buy", "afk", "skill"}) do s[key] = false end
        pcall(returnHome)
        repaint()
        say(pending and "Stopped. A sent purchase may still finish." or "All automation stopped.")
    end
    function manager.stop()
        if not s.alive then return end
        stopAll()
        s.alive = false
        for _, connection in ipairs(connections) do connection:Disconnect() end
        gui:Destroy()
        if env.LiftingHub == manager then env.LiftingHub = nil end
    end
    connect(gui.Destroying, function() manager.stop() end)
    local stats = label(farm, "Waiting for game data...", 90)
    toggle(farm, "Auto lift", "lift")
    local rates, rateAt = {5, 15, 30, 60}, 2
    local rateButton
    rateButton = button(farm, "Lift rate: 15 requests/sec (tap to change)", function()
        rateAt = rateAt % #rates + 1; s.rate = rates[rateAt]
        rateButton.Text = "Lift rate: " .. s.rate .. " requests/sec (tap to change)"
    end)
    label(farm, "Runs until stopped. The server decides how much muscle each accepted request awards.", 42)
    button(farm, "Save current position as sell area", function()
        local _, h, root = actor()
        assert(root and h and h.Health > 0 and not visit, "Wait for a live character outside a sell visit")
        spot = root.CFrame
        say("Sell position saved. Leave the area, then test a visit.")
    end)
    local function sellOnce()
        if visit then return end
        assert(spot, "Stand in the sell area and save its position first")
        local model, h, root = actor()
        if not root or not h or h.Health <= 0 then return end
        local before = num(data().Cash)
        send({"ChangeSetting", "SellEnabled", true})
        local current = {model = model, root = root, origin = root.CFrame}
        visit = current
        local good, problem = pcall(function()
            root.CFrame = spot
            root.AssemblyLinearVelocity = Vector3.zero
            local deadline = os.clock() + 2
            while s.alive and visit == current and os.clock() < deadline do task.wait(0.1) end
        end)
        local completed = visit == current
        if completed then returnHome() end
        if not good then error(problem) end
        if not s.alive or not completed then return end
        s.visits = s.visits + 1
        local after = num(data().Cash)
        say(before and after and after > before and ("Cash increased during visit: +" .. fmt(after - before))
            or "Visit finished; a sale has not been confirmed by a cash increase.")
    end
    button(farm, "Test one sell-area visit", sellOnce)
    toggle(farm, "Auto sell visits", "sell", function(enabled)
        if enabled and not spot then s.sell = false; say("Save a sell position first.") end
        if enabled then nextSell = 0 else returnHome() end
    end)
    local timings, timingAt = {10, 30, 60, 120}, 2
    local timing
    timing = button(farm, "Sell interval: 30 seconds (tap to change)", function()
        timingAt = timingAt % #timings + 1; s.interval = timings[timingAt]
        timing.Text = "Sell interval: " .. s.interval .. " seconds (tap to change)"
    end)
    local function idleInput()
        local good, problem = pcall(function()
            local v = game:GetService("VirtualUser")
            v:CaptureController(); v:ClickButton2(Vector2.new())
        end)
        if not good then s.afk = false; repaint(); say("Anti-AFK unavailable: " .. tostring(problem)) end
    end
    toggle(farm, "Anti-AFK attempt", "afk", function(enabled) if enabled then idleInput() end end)
    connect(player.Idled, function() if s.afk then idleInput() end end)
    connect(player.CharacterRemoving, returnHome)
    button(farm, "STOP EVERYTHING (F8)", stopAll)

    local goal = label(shop, "Loading weight catalog...", 90)
    label(shop, "Coin purchases only. Auto-buy submits one request and switches OFF. Purchases still need the normal price and prerequisites.", 58)
    local function target() return catalog and catalog.Income_Item and catalog.Income_Item[targetIndex] end
    local function owned(item, index)
        local d = data()
        local eq = type(d.EquipList) == "table" and tonumber(d.EquipList.Income)
        if eq == index then return true end
        local own = type(d.OwnList) == "table" and d.OwnList.Income_Item
        if type(own) ~= "table" then return nil end
        if own[item.Name] == true or own[index] == true or own[tostring(index)] == true then return true end
        local current = eq and catalog and catalog.Income_Item[eq]
        if current and (own[current.Name] == true or own[eq] == true or own[tostring(eq)] == true) then return false end
    end
    local function choose(step)
        assert(#targets > 0, "Wait for the catalog to load")
        selected = (selected - 1 + step) % #targets + 1
        targetIndex = targets[selected]; s.buy = false; repaint()
    end
    button(shop, "Previous weight", function() choose(-1) end)
    button(shop, "Next weight", function() choose(1) end)
    button(shop, "Select Toxic Tank", function()
        for i, index in ipairs(targets) do if index == 48 then selected = i; targetIndex = 48; s.buy = false; repaint(); return end end
        say("Toxic Tank is not in the loaded catalog.")
    end)
    local function buyOnce()
        assert(not pending, "A purchase is already awaiting confirmation")
        local item, cash = target(), num(data().Cash)
        assert(item and type(item.Price) == "number" and num(item.Price) and not item.VipItem and not item.GamePassItem,
            "Select a normal coin-priced weight")
        assert(cash and cash >= item.Price, "Not enough readable coins")
        if owned(item, targetIndex) == true then s.buy = false; repaint(); say("You already own this weight."); return end
        local _, h = actor()
        if not h or h.Health <= 0 or visit then return end
        s.buy = false; repaint()
        pending = {name = item.Name, index = targetIndex, time = os.clock()}
        local good, problem = pcall(send, {"BuyItem", "Income_Item", item.Name, targetIndex})
        if not good then pending = nil; error(problem) end
        say("Requested " .. item.Name .. ". Waiting for server confirmation; no automatic retry.")
    end
    toggle(shop, "Buy selected ONCE when affordable", "buy", function(enabled)
        if not enabled then return end
        local item = target()
        if pending or not item or not num(data().Cash) or owned(item, targetIndex) ~= false then
            s.buy = false; say("Need loaded cash, a known unowned target, and no pending purchase.")
        end
    end)
    button(shop, "Buy selected now if affordable", buyOnce)
    button(shop, "Equip selected owned weight", function()
        local item = target()
        assert(item and owned(item, targetIndex) == true, "Select a weight marked owned in game data")
        send({"EquipItem", "Income_Item", item.Name, targetIndex})
        say("Equip request sent. The game determines whether it succeeds.")
    end)

    label(tests, "Skills use your camera's center aim. Equip Poseidon or Hercules first. This does not change damage or grant unowned skills.", 58)
    local function useSkill()
        if os.clock() - lastSkill < 1.2 or visit then return end
        local model, h = actor()
        local tool = model and model:FindFirstChildOfClass("Tool")
        local skill = tool and ({Poseidon = "Skill3", Hercules = "Skill1"})[tool.Name]
        if not h or h.Health <= 0 or not skill then return false end
        local camera = workspace.CurrentCamera
        if not camera then return false end
        local size = camera.ViewportSize
        local aimRay = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
        lastSkill = os.clock()
        send({"Skill_Activated", aimRay, skill})
        return true
    end
    button(tests, "Use equipped skill once", function()
        say(useSkill() and "Skill activation requested." or "Equip Poseidon/Hercules, aim, and wait for the cooldown.")
    end)
    toggle(tests, "Repeat equipped skill (1.2 seconds)", "skill")
    local audit = label(tests, "Admin/gamepass checks are read-only. No server admin grant or pass bypass has been established from the supplied scripts.", 270)
    button(tests, "Check admin references and pass ownership", function()
        if checking then say("A check is already running."); return end
        assert(catalog, "Load the game modules first")
        checking = true
        local good, problem = pcall(function()
            local isListed = false
            for _, id in ipairs(catalog.AdminUserID or {}) do if tonumber(id) == player.UserId then isListed = true end end
            local main = parent:FindFirstChild("Main_Gui")
            local frame = main and main:FindFirstChild("Ban_Frame", true)
            local lines = {"Listed in CLIENT admin config: " .. tostring(isListed),
                "Ban_Frame exists locally: " .. tostring(frame ~= nil), "Neither result establishes server admin rights."}
            audit.Text = table.concat(lines, "\n")
            local flags = type(data().GamePass) == "table" and data().GamePass or {}
            local market = game:GetService("MarketplaceService")
            for _, key in ipairs({"DoubleStrength", "DoubleCoin", "DoubleDamage", "FastLifter", "VIP"}) do
                if not s.alive then return end
                local entry = catalog.GamePass and catalog.GamePass[key]
                local passId = type(entry) == "table" and tonumber(entry.Id)
                local passOK, result = false, "ID unavailable"
                if passId then passOK, result = pcall(function() return market:UserOwnsGamePassAsync(player.UserId, passId) end) end
                if not s.alive then return end
                table.insert(lines, key .. " | client: " .. tostring(flags[key]) .. " | Roblox: " .. (passOK and tostring(result) or "check unavailable"))
                audit.Text = table.concat(lines, "\n")
            end
        end)
        checking = false
        if not good then error(problem) end
    end)
    label(tests, "Temporary real pass benefits require a server testing override from your friend. Client flags and visible panels do not establish server permission.", 62)
    button(tests, "Stop and remove menu", manager.stop)

    local function receive(packet)
        if type(packet) ~= "table" then return end
        if packet[1] == "UpdateClientData" and type(packet[2]) == "table" then
            for key, value in pairs(packet[2]) do shadow[key] = value end
        elseif packet[1] == "UpdateMuscleOnClient" then shadow.Muscle = num(packet[2])
        elseif packet[1] == "UpdateBuyItemWithType" then shadow.Cash = num(packet[3])
        elseif packet[1] == "BuyItemComplete" and pending then
            local matches = packet[3] == "Income_Item" and packet[4] == pending.name and tonumber(packet[5]) == pending.index
            if packet[2] and matches then
                say("Server confirmed purchase: " .. pending.name); pending = nil
            elseif not packet[2] and (matches or packet[3] == nil) then
                say("Purchase failed while waiting. No automatic retry."); pending = nil
            end
        end
    end
    local function loadData()
        if loading then return end
        loading = true
        task.spawn(function()
            local good, problem = pcall(function()
                local event = RS:FindFirstChild("RemoteEvent")
                if event and event:IsA("RemoteEvent") and event ~= remote then
                    remote = event; connect(remote.OnClientEvent, receive)
                end
                local folder = RS:FindFirstChild("ClientModuleStorage")
                assert(folder, "ClientModuleStorage missing in this game")
                local definitions = folder:FindFirstChild("ClientDataStorage_Module")
                local live = folder:FindFirstChild("ClientRemoteController_Module")
                assert(definitions and live, "Expected client modules not found")
                local a, b = require(definitions), require(live)
                assert(type(a) == "table" and type(b) == "table", "Module format differs")
                if not s.alive then return end
                catalog, controller, targets = a, b, {}
                for index, item in ipairs(catalog.Income_Item or {}) do
                    if type(item) == "table" and type(item.Price) == "number" and num(item.Price)
                        and not item.VipItem and not item.GamePassItem then
                        table.insert(targets, index)
                        if index == targetIndex then selected = #targets end
                    end
                end
                say("Game modules loaded. Stand in the sell area and save its position.")
            end)
            loading = false
            if not good and s.alive then say("Data loading: " .. tostring(problem)) end
        end)
    end
    button(shop, "Reload game data", loadData)
    button(shop, "Reset coin tracking baseline", function() baseline, lastCash, increases = nil, nil, 0 end)
    local dragging, dragStart, panelStart, dragTouch
    connect(title.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, panelStart, dragTouch = true, input.Position, panel.Position, input
        end
    end)
    connect(Input.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input == dragTouch) then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset + delta.X, panelStart.Y.Scale, panelStart.Y.Offset + delta.Y)
        end
    end)
    connect(Input.InputEnded, function(input)
        if input == dragTouch or input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    connect(Input.InputBegan, function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.F8 then stopAll()
        elseif input.KeyCode == Enum.KeyCode.Insert then panel.Visible = not panel.Visible; reopen.Visible = not panel.Visible end
    end)
    local function refresh()
        local d, now = data(), os.clock()
        local cash = num(d.Cash)
        if cash then
            if baseline == nil then baseline = cash end
            if lastCash then increases = increases + math.max(0, cash - lastCash) end
            lastCash = cash
        end
        stats.Text = "Coins: " .. (cash and ("%.17g"):format(cash) or "waiting for data")
            .. "\nMuscle: " .. fmt(d.Muscle) .. " | Requests sent: " .. s.sent .. " | Visits: " .. s.visits
            .. "\nNet coins: " .. fmt(cash and cash - baseline) .. " | Observed increases: " .. fmt(increases)
        local item = target()
        goal.Text = item and (targetIndex .. " - " .. item.Name .. "\nPrice: " .. fmt(item.Price)
            .. " | Still needed: " .. fmt(cash and math.max(0, item.Price - cash))
            .. "\nOwned: " .. tostring(owned(item, targetIndex))) or "Waiting for the game's catalog. Try Reload game data."
        if pending then
            local bought = catalog and catalog.Income_Item[pending.index]
            if bought and owned(bought, pending.index) == true then
                say("Game data now marks " .. pending.name .. " as owned."); pending = nil
            elseif now - pending.time >= 15 then
                say("No matching purchase confirmation. Check the normal shop before trying again."); pending = nil
            end
        end
        if s.buy and not pending and item then
            local ownership = owned(item, targetIndex)
            if ownership ~= false then s.buy = false; repaint()
            elseif cash and cash >= item.Price then buyOnce() end
        end
    end
    task.spawn(function()
        while s.alive do
            if s.lift and not visit and remote then
                local _, h = actor()
                if h and h.Health > 0 then
                    local good, problem = pcall(send, {"GainMuscle"})
                    if good then s.sent = s.sent + 1 else s.lift = false; repaint(); say(problem) end
                end
            end
            task.wait(s.lift and 1 / s.rate or 0.1)
        end
    end)
    task.spawn(function()
        while s.alive do
            if s.sell and spot and not visit and remote and os.clock() >= nextSell then
                local good, problem = pcall(sellOnce)
                nextSell = os.clock() + s.interval
                if not good then s.sell = false; repaint(); say(problem) end
            end
            task.wait(0.2)
        end
    end)
    task.spawn(function()
        while s.alive do
            if s.skill and remote then
                local good, problem = pcall(useSkill)
                if not good then s.skill = false; repaint(); say(problem) end
            end
            local good, problem = pcall(refresh)
            if not good then s.buy = false; repaint(); say(problem) end
            task.wait(0.5)
        end
    end)
    say("Ready. Farm / Shop / Skills tabs above. F8 stops automation; Insert hides or shows.")
    loadData()
end, function(problem) return tostring(problem) end)
if not bootOK then
    warn("[Lifting Hub] Startup: " .. tostring(bootError))
    pcall(function()
        local p = game:GetService("Players").LocalPlayer
        local g = p and p:FindFirstChild("PlayerGui")
        local hub = g and g:FindFirstChild("LiftingHubFixed")
        local status = hub and hub:FindFirstChild("HubStatus", true)
        if status then status.Text = "Startup error: " .. tostring(bootError) end
    end)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Lifting Hub startup error", Text = tostring(bootError):sub(1, 180), Duration = 20})
    end)
    return false, tostring(bootError)
end
return true, "Lifting Hub initialized"
