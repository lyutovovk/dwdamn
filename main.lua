--[[ 
    DANDY'S WORLD: POORLY SCRIPTED STUFF v2.7
    macOS / iOS 25 Aesthetic Library + Smart ESP
    Updated: Real-time Player HP Tracking (Stats -> Health)
    Features: Teleports to Elevator, Named Twisteds/Items, Fixed WalkSpeed
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--// THEME CONFIGURATION
local Theme = {
    Background = Color3.fromRGB(25, 25, 35),
    Sidebar = Color3.fromRGB(20, 20, 30),
    Text = Color3.fromRGB(240, 240, 240),
    TextDim = Color3.fromRGB(120, 120, 130),
    Accent = Color3.fromRGB(10, 132, 255),
    Stroke = Color3.fromRGB(60, 60, 70),
    CornerRadius = UDim.new(0, 16)
}

local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

--// FEATURE SETTINGS
local ESP_Settings = {
    Players = {Enabled = false, Color = Color3.fromRGB(0, 255, 100)},
    Twisteds = {Enabled = false, Color = Color3.fromRGB(255, 50, 50)},
    Generators = {Enabled = false, Color = Color3.fromRGB(255, 220, 0)},
    Items = {Enabled = false, Color = Color3.fromRGB(0, 200, 255)},
}

local WalkSpeedEnabled = false
local WalkSpeedValue = 24
local ESP_Storage = {} 

--// UTILITY: ESP FUNCTIONS
local function GetPlayerHealth(plr)
    local char = plr.Character
    if char then
        -- Updated: Targeted check for Stats > Health from screenshots
        local stats = char:FindFirstChild("Stats")
        if stats then
            local healthVal = stats:FindFirstChild("Health")
            if healthVal then
                return tostring(healthVal.Value)
            end
        end
    end
    return "?" -- Return placeholder if data is missing
end

local function CreateHighlight(model, color, name, isPlayer, playerObj, showBillboard)
    if not model then return end
    
    -- Real-time update logic: If the Billboard already exists, just update the text
    local existingBillboard = model:FindFirstChild("DW_ESP_Text")
    if existingBillboard and isPlayer and playerObj then
        existingBillboard.TextLabel.Text = playerObj.Name .. " (" .. GetPlayerHealth(playerObj) .. ")"
        return 
    end

    if model:FindFirstChild("DW_ESP") then return end 

    -- Create new Highlight
    local highlight = Instance.new("Highlight")
    highlight.Name = "DW_ESP"
    highlight.Adornee = model
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.1
    highlight.Parent = model

    -- Create new Billboard
    local billboard
    if showBillboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "DW_ESP_Text"
        billboard.Adornee = model
        billboard.Size = UDim2.new(0, 150, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 4, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = model

        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        -- Initial text setting
        text.Text = isPlayer and (playerObj.Name .. " (" .. GetPlayerHealth(playerObj) .. ")") or name
        text.TextColor3 = color
        text.TextStrokeTransparency = 0
        text.Font = Enum.Font.GothamBold
        text.TextSize = 13
        text.Parent = billboard
    end

    table.insert(ESP_Storage, {Instance = highlight, Billboard = billboard, Parent = model, Type = name, IsPlayer = isPlayer, PlrObj = playerObj})
end

local function RefreshESP()
    -- Cleanup and Update Loop
    for i = #ESP_Storage, 1, -1 do
        local data = ESP_Storage[i]
        local shouldExist = false
        
        if data.Type == "Generator" and ESP_Settings.Generators.Enabled then shouldExist = true
        elseif data.IsPlayer and ESP_Settings.Players.Enabled then shouldExist = true
        elseif ESP_Settings.Twisteds.Enabled and data.Type == "Twisted" then shouldExist = true
        elseif ESP_Settings.Items.Enabled and data.Type == "Item" then shouldExist = true end

        if not shouldExist or not data.Parent or not data.Parent.Parent then
            if data.Instance then data.Instance:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
            table.remove(ESP_Storage, i)
        end
    end

    -- Update Players
    if ESP_Settings.Players.Enabled then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                CreateHighlight(plr.Character, ESP_Settings.Players.Color, plr.Name, true, plr, true)
            end
        end
    end

    -- Update World Objects
    local currentRoomFolder = Workspace:FindFirstChild("CurrentRoom")
    if currentRoomFolder then
        local roomModel = currentRoomFolder:GetChildren()[1]
        if roomModel then
            -- Twisteds
            if ESP_Settings.Twisteds.Enabled then
                local monsterFolder = roomModel:FindFirstChild("Monsters")
                if monsterFolder then
                    for _, mob in pairs(monsterFolder:GetChildren()) do
                        local twistedName = "Twisted " .. mob.Name
                        CreateHighlight(mob, ESP_Settings.Twisteds.Color, "Twisted", false, nil, true)
                        if mob:FindFirstChild("DW_ESP_Text") then
                            mob.DW_ESP_Text.TextLabel.Text = twistedName
                        end
                    end
                end
            end
            
            -- Generators
            if ESP_Settings.Generators.Enabled then
                local genFolder = roomModel:FindFirstChild("Generators")
                if genFolder then
                    for _, gen in pairs(genFolder:GetChildren()) do
                        CreateHighlight(gen, ESP_Settings.Generators.Color, "Generator", false, nil, false)
                    end
                end
            end

            -- Items
            if ESP_Settings.Items.Enabled then
                local itemFolder = roomModel:FindFirstChild("Items")
                if itemFolder then
                    for _, item in pairs(itemFolder:GetChildren()) do
                        CreateHighlight(item, ESP_Settings.Items.Color, item.Name, false, nil, true)
                    end
                end
            end
        end
    end
end

RunService.Stepped:Connect(RefreshESP)

-- WalkSpeed Handler
task.spawn(function()
    while task.wait() do
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local hum = LocalPlayer.Character.Humanoid
                if WalkSpeedEnabled then
                    if hum.WalkSpeed < WalkSpeedValue then
                        hum.WalkSpeed = WalkSpeedValue
                    end
                else
                    if hum.WalkSpeed == WalkSpeedValue then
                        hum.WalkSpeed = 16
                    end
                end
            end
        end)
    end
end)

--// GUI LIBRARY (macOS Style)
local Library = {}

function Library:Init()
    if CoreGui:FindFirstChild("DandysWorld_macOS") then CoreGui.DandysWorld_macOS:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DandysWorld_macOS"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "Window"
    MainFrame.Size = UDim2.new(0, 400, 0, 250) 
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -125)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BackgroundTransparency = 1 
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui

    TweenService:Create(MainFrame, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 650, 0, 420),
        Position = UDim2.new(0.5, -325, 0.5, -210),
        BackgroundTransparency = 0.15
    }):Play()

    local MainCorner = Instance.new("UICorner", MainFrame)
    MainCorner.CornerRadius = Theme.CornerRadius

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 180, 1, 0)
    Sidebar.BackgroundColor3 = Theme.Sidebar
    Sidebar.BackgroundTransparency = 0.5
    Sidebar.Parent = MainFrame

    local ContentPageHolder = Instance.new("Frame")
    ContentPageHolder.Size = UDim2.new(1, -180, 1, 0)
    ContentPageHolder.Position = UDim2.new(0, 180, 0, 0)
    ContentPageHolder.BackgroundTransparency = 1
    ContentPageHolder.Parent = MainFrame

    local ControlsHolder = Instance.new("Frame")
    ControlsHolder.Size = UDim2.new(0, 60, 0, 20)
    ControlsHolder.Position = UDim2.new(0, 18, 0, 18)
    ControlsHolder.BackgroundTransparency = 1
    ControlsHolder.Parent = MainFrame

    local function CreateDot(color, offset)
        local Dot = Instance.new("Frame")
        Dot.Size = UDim2.new(0, 12, 0, 12)
        Dot.Position = UDim2.new(0, offset, 0, 0)
        Dot.BackgroundColor3 = color
        Dot.Parent = ControlsHolder
        Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)
        local Btn = Instance.new("TextButton", Dot)
        Btn.Size = UDim2.new(1,0,1,0)
        Btn.BackgroundTransparency = 1
        Btn.Text = ""
        return Btn
    end

    local CloseBtn = CreateDot(Color3.fromRGB(255, 95, 87), 0)
    local HideBtn = CreateDot(Color3.fromRGB(255, 189, 46), 20)
    local OpenBtn = CreateDot(Color3.fromRGB(40, 200, 64), 40)

    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)
    
    HideBtn.MouseButton1Click:Connect(function()
        TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 80, 0, 45)}):Play()
        Sidebar.Visible = false
        ContentPageHolder.Visible = false
    end)

    OpenBtn.MouseButton1Click:Connect(function()
        TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = UDim2.new(0, 650, 0, 420)}):Play()
        task.wait(0.1)
        Sidebar.Visible = true
        ContentPageHolder.Visible = true
    end)

    local Dragging, DragInput, DragStart, StartPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            DragStart = input.Position
            StartPos = MainFrame.Position
        end
    end)
    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then DragInput = input end
    end)
    RunService.RenderStepped:Connect(function()
        if Dragging and DragInput then
            local Delta = DragInput.Position - DragStart
            MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + Delta.X, StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y)
        end
    end)

    local Title = Instance.new("TextLabel")
    Title.Text = "Poorly Scripted"
    Title.TextColor3 = Theme.TextDim
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 13
    Title.Size = UDim2.new(1, -40, 0, 20)
    Title.Position = UDim2.new(0, 20, 0, 60)
    Title.BackgroundTransparency = 1
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Sidebar

    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Size = UDim2.new(1, -20, 1, -100)
    TabContainer.Position = UDim2.new(0, 10, 0, 90)
    TabContainer.BackgroundTransparency = 1
    TabContainer.ScrollBarThickness = 0
    TabContainer.Parent = Sidebar
    Instance.new("UIListLayout", TabContainer).Padding = UDim.new(0, 5)

    local Tabs = {}
    local FirstTab = true
    function Tabs:CreateTab(Name)
        local TabData = {}
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, 0, 0, 34)
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = "    " .. Name
        TabBtn.TextColor3 = Theme.TextDim
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 14
        TabBtn.TextXAlignment = Enum.TextXAlignment.Left
        TabBtn.Parent = TabContainer
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)

        local Page = Instance.new("ScrollingFrame")
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.Visible = false
        Page.ScrollBarThickness = 0
        Page.Parent = ContentPageHolder
        Instance.new("UIListLayout", Page).Padding = UDim.new(0, 10)
        local Pad = Instance.new("UIPadding", Page)
        Pad.PaddingTop = UDim.new(0,20) Pad.PaddingLeft = UDim.new(0,20) Pad.PaddingRight = UDim.new(0,20)

        local function Activate()
            for _, c in pairs(TabContainer:GetChildren()) do if c:IsA("TextButton") then c.BackgroundTransparency = 1 c.TextColor3 = Theme.TextDim end end
            for _, c in pairs(ContentPageHolder:GetChildren()) do if c:IsA("ScrollingFrame") then c.Visible = false end end
            Page.Visible = true
            TabBtn.BackgroundTransparency = 0.9
            TabBtn.TextColor3 = Theme.Text
        end
        TabBtn.MouseButton1Click:Connect(Activate)
        if FirstTab then Activate() FirstTab = false end

        function TabData:CreateToggle(Text, Callback)
            local ToggleFrame = Instance.new("Frame", Page)
            ToggleFrame.Size = UDim2.new(1, 0, 0, 40)
            ToggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            ToggleFrame.BackgroundTransparency = 0.5
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 10)
            
            local Label = Instance.new("TextLabel", ToggleFrame)
            Label.Text = "  " .. Text
            Label.Size = UDim2.new(0.7, 0, 1, 0)
            Label.BackgroundTransparency = 1
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.Gotham
            Label.TextSize = 14
            Label.TextXAlignment = Enum.TextXAlignment.Left

            local SwitchBg = Instance.new("Frame", ToggleFrame)
            SwitchBg.Size = UDim2.new(0, 44, 0, 24)
            SwitchBg.Position = UDim2.new(1, -55, 0.5, -12)
            SwitchBg.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

            local SwitchCircle = Instance.new("Frame", SwitchBg)
            SwitchCircle.Size = UDim2.new(0, 20, 0, 20)
            SwitchCircle.Position = UDim2.new(0, 2, 0.5, -10)
            SwitchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", SwitchCircle).CornerRadius = UDim.new(1, 0)

            local Toggled = false
            local Trigger = Instance.new("TextButton", ToggleFrame)
            Trigger.Size = UDim2.new(1, 0, 1, 0)
            Trigger.BackgroundTransparency = 1
            Trigger.Text = ""

            Trigger.MouseButton1Click:Connect(function()
                Toggled = not Toggled
                TweenService:Create(SwitchBg, TweenInfo.new(0.3), {BackgroundColor3 = Toggled and Theme.Accent or Color3.fromRGB(60, 60, 70)}):Play()
                TweenService:Create(SwitchCircle, TweenInfo.new(0.3), {Position = Toggled and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}):Play()
                Callback(Toggled)
            end)
        end

        function TabData:CreateSlider(Text, Min, Max, Default, Callback)
            local SliderFrame = Instance.new("Frame", Page)
            SliderFrame.Size = UDim2.new(1, 0, 0, 50)
            SliderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            SliderFrame.BackgroundTransparency = 0.5
            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 10)

            local Label = Instance.new("TextLabel", SliderFrame)
            Label.Text = "  " .. Text .. ": " .. Default
            Label.Size = UDim2.new(1, 0, 0, 25)
            Label.BackgroundTransparency = 1
            Label.TextColor3 = Theme.Text
            Label.Font = Enum.Font.Gotham
            Label.TextSize = 13
            Label.TextXAlignment = Enum.TextXAlignment.Left

            local SliderBar = Instance.new("Frame", SliderFrame)
            SliderBar.Size = UDim2.new(1, -40, 0, 4)
            SliderBar.Position = UDim2.new(0, 20, 0, 35)
            SliderBar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            Instance.new("UICorner", SliderBar)

            local SliderFill = Instance.new("Frame", SliderBar)
            SliderFill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
            SliderFill.BackgroundColor3 = Theme.Accent
            Instance.new("UICorner", SliderFill)

            local function UpdateSlider(Input)
                local Size = math.clamp((Input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
                SliderFill.Size = UDim2.new(Size, 0, 1, 0)
                local Value = math.floor(Min + (Max - Min) * Size)
                Label.Text = "  " .. Text .. ": " .. Value
                Callback(Value)
            end

            SliderBar.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    UpdateSlider(input)
                    local Connection; Connection = UserInputService.InputChanged:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseMovement then UpdateSlider(input) end
                    end)
                    UserInputService.InputEnded:Connect(function(input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then Connection:Disconnect() end
                    end)
                end
            end)
        end

        function TabData:CreateButton(Text, Callback)
            local ButtonFrame = Instance.new("Frame", Page)
            ButtonFrame.Size = UDim2.new(1, 0, 0, 40)
            ButtonFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            ButtonFrame.BackgroundTransparency = 0.5
            Instance.new("UICorner", ButtonFrame).CornerRadius = UDim.new(0, 10)

            local Btn = Instance.new("TextButton", ButtonFrame)
            Btn.Size = UDim2.new(1, 0, 1, 0)
            Btn.BackgroundTransparency = 1
            Btn.Text = Text
            Btn.TextColor3 = Theme.Text
            Btn.Font = Enum.Font.GothamMedium
            Btn.TextSize = 14

            Btn.MouseButton1Click:Connect(Callback)
        end
        return TabData
    end
    return Tabs
end

--// INIT
local Window = Library:Init()
local MainTab = Window:CreateTab("Main")

MainTab:CreateToggle("Enable WalkSpeed", function(val) WalkSpeedEnabled = val end)
MainTab:CreateSlider("WalkSpeed Value", 16, 150, 24, function(val) WalkSpeedValue = val end)

local VisualsTab = Window:CreateTab("Visuals")
VisualsTab:CreateToggle("ESP Twisteds", function(val) ESP_Settings.Twisteds.Enabled = val end)
VisualsTab:CreateToggle("ESP Generators", function(val) ESP_Settings.Generators.Enabled = val end)
VisualsTab:CreateToggle("ESP Items", function(val) ESP_Settings.Items.Enabled = val end)
VisualsTab:CreateToggle("ESP Players", function(val) ESP_Settings.Players.Enabled = val end)

local TeleportTab = Window:CreateTab("Teleports")
TeleportTab:CreateButton("Teleport to Elevator", function()
    pcall(function()
        local elevatorFolder = Workspace:FindFirstChild("Elevators")
        if elevatorFolder then
            local elevator = elevatorFolder:FindFirstChild("Elevator")
            if elevator then
                local spawnZones = elevator:FindFirstChild("SpawnZones")
                if spawnZones and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local target = spawnZones:IsA("BasePart") and spawnZones or spawnZones:FindFirstChildOfClass("BasePart")
                    LocalPlayer.Character.HumanoidRootPart.CFrame = target.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end
    end)
end)

local StuffTab = Window:CreateTab("Stuff")
StuffTab:CreateToggle("Fullbright", function(val)
    if val then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    else
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.GlobalShadows = OriginalLighting.GlobalShadows
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    end
end)

print("Poorly Scripted v2.7 - Real-time HP Tracking & Elevator TPs")
