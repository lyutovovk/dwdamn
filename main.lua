--[[ 
    DANDY'S WORLD: POORLY SCRIPTED STUFF v6.7
    macOS / iOS 25 Aesthetic Library + Smart ESP
    Updated: FIXED HEART ESP (Direct Stats Reading)
    Features: Auto Skillcheck, Smart Noclip, Real-time HP, Gen Rush, Auto Collect
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--// THEME CONFIGURATION
local Theme = {
    Background = Color3.fromRGB(18, 18, 24),
    Sidebar = Color3.fromRGB(23, 23, 30),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(160, 160, 175),
    Accent = Color3.fromRGB(0, 122, 255), -- iOS Blue
    Stroke = Color3.fromRGB(60, 60, 80),
    Success = Color3.fromRGB(50, 205, 50),
    Destructive = Color3.fromRGB(255, 59, 48), -- iOS Red
    CornerRadius = UDim.new(0, 14)
}

--// AUDIO SYSTEM
local SoundEnabled = true 
local SoundAssets = {
    Hover = "rbxassetid://6895079853",
    Click = "rbxassetid://1412830636",
    Notify = "rbxassetid://87437544236708"
}
local LoadedSounds = {}

local function PreloadSounds()
    local SoundFolder = Instance.new("Folder")
    SoundFolder.Name = "DW_Script_Sounds"
    SoundFolder.Parent = SoundService
    
    for name, id in pairs(SoundAssets) do
        local s = Instance.new("Sound")
        s.Name = name
        s.SoundId = id
        s.Volume = 0.5 
        s.Parent = SoundFolder
        LoadedSounds[name] = s
    end
    ContentProvider:PreloadAsync(SoundFolder:GetChildren())
end
task.spawn(PreloadSounds)

local function PlayAudio(name)
    if not SoundEnabled then return end
    local sound = LoadedSounds[name]
    if sound then sound:Play() end
end

--// FEATURE SETTINGS
local ESP_Settings = {
    Players = {Enabled = false, Color = Color3.fromRGB(170, 0, 255)}, -- Purple
    Twisteds = {Enabled = false, Color = Color3.fromRGB(255, 50, 50)},
    Generators = {Enabled = false, Color = Color3.fromRGB(255, 255, 255)},
    Items = {Enabled = false, Color = Color3.fromRGB(0, 200, 255)},
}

local WalkSpeedEnabled = false
local WalkSpeedValue = 24
local NoclipEnabled = false
local AutoSkillCheckEnabled = false
local AutoEscapeEnabled = false 
local NoclipConnection = nil
local ESP_Storage = {} 

-- Global Keybind Variables
local ToggleKey = Enum.KeyCode.LeftControl 
local IsMenuOpen = true 
local IsSettingKeybind = false 

--// UTILITY: FUNCTIONS
local function GetHeartsFromModel(model)
    local hp = 3 -- Default
    local stats = model:FindFirstChild("Stats")
    
    if stats then
        local healthVal = stats:FindFirstChild("Health")
        if healthVal then
            hp = healthVal.Value
        end
    end

    -- Convert to Hearts string
    local hearts = ""
    for i = 1, math.floor(hp) do
        hearts = hearts .. "❤"
    end
    if hp <= 0 then hearts = "☠️" end
    return hearts
end

local function CreateHighlight(model, color, name, isPlayer, showBillboard)
    if not model then return end
    
    local existingBillboard = model:FindFirstChild("DW_ESP_Text")
    
    -- REAL-TIME UPDATE FOR PLAYERS
    if existingBillboard and isPlayer then
        existingBillboard.TextLabel.Text = model.Name .. "\n" .. GetHeartsFromModel(model)
        return 
    end

    if model:FindFirstChild("DW_ESP") then return end 

    local highlight = Instance.new("Highlight")
    highlight.Name = "DW_ESP"
    highlight.Adornee = model
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0.1
    highlight.Parent = model

    local billboard
    if showBillboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "DW_ESP_Text"
        billboard.Adornee = model
        billboard.Size = UDim2.new(0, 150, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = model

        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        
        if isPlayer then
            text.Text = model.Name .. "\n" .. GetHeartsFromModel(model)
        else
            text.Text = name
        end
        
        text.TextColor3 = color
        text.TextStrokeTransparency = 0
        text.Font = Enum.Font.GothamBold
        text.TextSize = 13
        text.Parent = billboard
    end

    table.insert(ESP_Storage, {Instance = highlight, Billboard = billboard, Parent = model, Type = name, IsPlayer = isPlayer})
end

local function RefreshESP()
    -- Cleanup Invalid
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

    --// 1. PLAYERS (Scanning InGamePlayers Folder Directly)
    if ESP_Settings.Players.Enabled then
        local igPlayers = Workspace:FindFirstChild("InGamePlayers")
        if igPlayers then
            for _, charModel in pairs(igPlayers:GetChildren()) do
                if charModel.Name ~= LocalPlayer.Name and charModel:FindFirstChild("HumanoidRootPart") then
                    CreateHighlight(charModel, ESP_Settings.Players.Color, charModel.Name, true, true)
                end
            end
        end
    end

    --// 2. ROOM OBJECTS
    local currentRoomFolder = Workspace:FindFirstChild("CurrentRoom")
    if currentRoomFolder then
        local roomModel = currentRoomFolder:GetChildren()[1]
        if roomModel then
            -- Twisteds
            if ESP_Settings.Twisteds.Enabled then
                local monsterFolder = roomModel:FindFirstChild("Monsters")
                if monsterFolder then
                    for _, mob in pairs(monsterFolder:GetChildren()) do
                        local cleanName = mob.Name:gsub("Monster", "")
                        local twistedName = "Twisted " .. cleanName
                        CreateHighlight(mob, ESP_Settings.Twisteds.Color, "Twisted", false, true)
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
                        local isCompleted = false
                        if gen:FindFirstChild("Stats") and gen.Stats:FindFirstChild("Completed") then
                            isCompleted = gen.Stats.Completed.Value
                        end
                        local targetColor = isCompleted and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 255, 255)
                        local existing = gen:FindFirstChild("DW_ESP")
                        if existing then
                            if existing.FillColor ~= targetColor then
                                existing.FillColor = targetColor
                                existing.OutlineColor = targetColor
                            end
                        else
                            CreateHighlight(gen, targetColor, "Generator", false, false)
                        end
                    end
                end
            end

            -- Items
            if ESP_Settings.Items.Enabled then
                local itemFolder = roomModel:FindFirstChild("Items")
                if itemFolder then
                    for _, item in pairs(itemFolder:GetChildren()) do
                        CreateHighlight(item, ESP_Settings.Items.Color, item.Name, false, true)
                    end
                end
            end
        end
    end
end

RunService.Stepped:Connect(RefreshESP)

--// SMART NOCLIP
local function ModifyPartCollision(part, noclipActive)
    if not part:IsA("BasePart") then return end
    local name = part.Name:lower()
    if name:find("floor") or name:find("ground") or name:find("base") then return end
    part.CanCollide = not noclipActive
end

local function ToggleNoclipSystem(enable)
    local cr = Workspace:FindFirstChild("CurrentRoom")
    if enable then
        if cr then for _, v in pairs(cr:GetDescendants()) do ModifyPartCollision(v, true) end end
        if NoclipConnection then NoclipConnection:Disconnect() end
        NoclipConnection = Workspace.DescendantAdded:Connect(function(descendant)
            if NoclipEnabled and descendant:IsDescendantOf(Workspace:FindFirstChild("CurrentRoom")) then
                task.wait() 
                ModifyPartCollision(descendant, true)
            end
        end)
    else
        if NoclipConnection then NoclipConnection:Disconnect() NoclipConnection = nil end
        if cr then for _, v in pairs(cr:GetDescendants()) do ModifyPartCollision(v, false) end end
    end
end

--// AUTO SKILLCHECK
local function AttemptAutoSkillcheck()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return end

    local screenGui = pGui:FindFirstChild("ScreenGui")
    if screenGui then
        local menu = screenGui:FindFirstChild("Menu")
        if menu then
            local skillFrame = menu:FindFirstChild("SkillCheckFrame")
            if skillFrame and skillFrame.Visible then
                local Marker = skillFrame:FindFirstChild("Marker")
                local GoldZone = skillFrame:FindFirstChild("GoldArea")
                if Marker and GoldZone and Marker.Visible and GoldZone.Visible then
                    local cursorX = Marker.AbsolutePosition.X
                    local goldX_Min = GoldZone.AbsolutePosition.X
                    local goldX_Max = GoldZone.AbsolutePosition.X + GoldZone.AbsoluteSize.X
                    if cursorX >= goldX_Min and cursorX <= goldX_Max then
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        RunService.RenderStepped:Wait()
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        task.wait(1.5) 
                    end
                end
            end
        end
    end

    local circleGui = pGui:FindFirstChild("CircleSkillCheckGui")
    if circleGui and circleGui.Enabled then
        local frame = circleGui:FindFirstChild("SkillCheckFrame")
        if frame then
            local container = frame:FindFirstChild("Container")
            if container then
                local shrinking = container:FindFirstChild("ShrinkingCircle")
                local yellow = container:FindFirstChild("YellowCircle")
                if shrinking and yellow and shrinking.Visible and yellow.Visible then
                    local sSize = shrinking.AbsoluteSize.X
                    local ySize = yellow.AbsoluteSize.X
                    if sSize <= ySize and sSize >= (ySize - 25) then
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                        RunService.RenderStepped:Wait()
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
                        task.wait(1) 
                    end
                end
            end
        end
    end

    local treadmillGui = pGui:FindFirstChild("TreadmillTapSkillCheckGui")
    if treadmillGui and treadmillGui.Enabled then
        local viewportSize = workspace.CurrentCamera.ViewportSize
        VirtualInputManager:SendMouseButtonEvent(viewportSize.X/2, viewportSize.Y/2, 0, true, game, 1)
        RunService.RenderStepped:Wait()
        VirtualInputManager:SendMouseButtonEvent(viewportSize.X/2, viewportSize.Y/2, 0, false, game, 1)
        task.wait(math.random(5, 15) / 100) 
    end
end

RunService.RenderStepped:Connect(function()
    if AutoSkillCheckEnabled then
        AttemptAutoSkillcheck()
    end
end)

--// AUTO ESCAPE LOGIC
local PanicTeleported = false
task.spawn(function()
    while task.wait(0.5) do
        if AutoEscapeEnabled then
            pcall(function()
                local info = Workspace:FindFirstChild("Info")
                if info then
                    local panicVal = info:FindFirstChild("Panic")
                    if panicVal and panicVal.Value == true then
                        if not PanicTeleported then
                            local elevatorFolder = Workspace:FindFirstChild("Elevators")
                            if elevatorFolder then
                                local elevator = elevatorFolder:FindFirstChild("Elevator")
                                if elevator then
                                    local spawnZones = elevator:FindFirstChild("SpawnZones")
                                    if spawnZones and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                        local target = spawnZones:IsA("BasePart") and spawnZones or spawnZones:FindFirstChildOfClass("BasePart")
                                        if target then
                                            LocalPlayer.Character.HumanoidRootPart.CFrame = target.CFrame + Vector3.new(0, 3, 0)
                                            PanicTeleported = true 
                                        end
                                    end
                                end
                            end
                        end
                    else
                        PanicTeleported = false
                    end
                end
            end)
        else
            PanicTeleported = false
        end
    end
end)

-- WalkSpeed Handler
task.spawn(function()
    while task.wait() do
        pcall(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                local hum = LocalPlayer.Character.Humanoid
                if WalkSpeedEnabled then
                    if hum.WalkSpeed < WalkSpeedValue then hum.WalkSpeed = WalkSpeedValue end
                else
                    if hum.WalkSpeed == WalkSpeedValue then hum.WalkSpeed = 16 end
                end
            end
        end)
    end
end)

--// GUI LIBRARY
local Library = {}
local NotificationHolder

function Library:Notify(Title, Text, Duration)
    PlayAudio("Notify")
    if not NotificationHolder then return end
    
    local NotifyFrame = Instance.new("Frame")
    NotifyFrame.Size = UDim2.new(1, 0, 0, 0)
    NotifyFrame.BackgroundColor3 = Theme.Sidebar
    NotifyFrame.BackgroundTransparency = 0.1
    NotifyFrame.BorderSizePixel = 0
    NotifyFrame.ClipsDescendants = true
    NotifyFrame.Parent = NotificationHolder
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Theme.Stroke
    Stroke.Thickness = 1
    Stroke.Parent = NotifyFrame
    
    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = NotifyFrame
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Text = Title
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = 14
    TitleLabel.TextColor3 = Theme.Accent
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Size = UDim2.new(1, -20, 0, 20)
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = NotifyFrame
    
    local DescLabel = Instance.new("TextLabel")
    DescLabel.Text = Text
    DescLabel.Font = Enum.Font.Gotham
    DescLabel.TextSize = 12
    DescLabel.TextColor3 = Theme.Text
    DescLabel.BackgroundTransparency = 1
    DescLabel.Size = UDim2.new(1, -20, 0, 30)
    DescLabel.Position = UDim2.new(0, 10, 0, 22)
    DescLabel.TextXAlignment = Enum.TextXAlignment.Left
    DescLabel.TextWrapped = true
    DescLabel.Parent = NotifyFrame
    
    NotifyFrame:TweenSize(UDim2.new(1, 0, 0, 60), Enum.EasingDirection.Out, Enum.EasingStyle.Quart, 0.3, true)
    
    task.delay(Duration or 3, function()
        NotifyFrame:TweenSize(UDim2.new(1, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quart, 0.3, true, function()
            NotifyFrame:Destroy()
        end)
    end)
end

function Library:Init()
    if PlayerGui:FindFirstChild("DandysWorld_macOS") then PlayerGui.DandysWorld_macOS:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "DandysWorld_macOS"
    ScreenGui.Parent = PlayerGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true

    --// SMOOTHER WELCOME SCREEN //
    local WelcomeBlur = Instance.new("Frame")
    WelcomeBlur.Size = UDim2.new(1,0,1,0)
    WelcomeBlur.BackgroundColor3 = Color3.fromRGB(0,0,0)
    WelcomeBlur.BackgroundTransparency = 0.5
    WelcomeBlur.Parent = ScreenGui
    
    local WelcomeFrame = Instance.new("Frame")
    WelcomeFrame.Name = "WelcomeFrame"
    WelcomeFrame.Size = UDim2.new(0, 0, 0, 0)
    WelcomeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    WelcomeFrame.BackgroundColor3 = Theme.Background
    WelcomeFrame.BorderSizePixel = 0
    WelcomeFrame.ClipsDescendants = true
    WelcomeFrame.Parent = ScreenGui
    
    local WelcomeCorner = Instance.new("UICorner", WelcomeFrame)
    WelcomeCorner.CornerRadius = Theme.CornerRadius
    local WelcomeStroke = Instance.new("UIStroke", WelcomeFrame)
    WelcomeStroke.Color = Theme.Accent
    WelcomeStroke.Thickness = 2

    local Avatar = Instance.new("ImageLabel")
    Avatar.Size = UDim2.new(0, 80, 0, 80)
    Avatar.Position = UDim2.new(0.5, -40, 0.2, 0)
    Avatar.BackgroundTransparency = 1
    Avatar.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
    Avatar.Parent = WelcomeFrame
    Instance.new("UICorner", Avatar).CornerRadius = UDim.new(1, 0)

    local WelcomeText = Instance.new("TextLabel")
    WelcomeText.Text = "Welcome Back, " .. LocalPlayer.DisplayName
    WelcomeText.Size = UDim2.new(1, 0, 0, 25)
    WelcomeText.Position = UDim2.new(0, 0, 0.6, 0)
    WelcomeText.BackgroundTransparency = 1
    WelcomeText.TextColor3 = Theme.Text
    WelcomeText.Font = Enum.Font.GothamBold
    WelcomeText.TextSize = 18
    WelcomeText.Parent = WelcomeFrame

    local LoadingText = Instance.new("TextLabel")
    LoadingText.Text = "Initializing..."
    LoadingText.Size = UDim2.new(1, 0, 0, 20)
    LoadingText.Position = UDim2.new(0, 0, 0.75, 0)
    LoadingText.BackgroundTransparency = 1
    LoadingText.TextColor3 = Theme.TextDim
    LoadingText.Font = Enum.Font.Gotham
    LoadingText.TextSize = 14
    LoadingText.Parent = WelcomeFrame

    TweenService:Create(WelcomeFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 320, 0, 200),
        Position = UDim2.new(0.5, -160, 0.5, -100)
    }):Play()
    
    task.wait(1)
    LoadingText.Text = "Loading Assets..."
    task.wait(0.8)
    LoadingText.Text = "Injecting..."
    task.wait(0.8)
    
    TweenService:Create(WelcomeFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)}):Play()
    TweenService:Create(WelcomeBlur, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
    task.wait(0.4)
    WelcomeFrame:Destroy()
    WelcomeBlur:Destroy()

    NotificationHolder = Instance.new("Frame")
    NotificationHolder.Name = "Notifications"
    NotificationHolder.Size = UDim2.new(0, 250, 1, -20)
    NotificationHolder.Position = UDim2.new(1, -270, 0, 10)
    NotificationHolder.BackgroundTransparency = 1
    NotificationHolder.Parent = ScreenGui
    
    local UIList = Instance.new("UIListLayout")
    UIList.Padding = UDim.new(0, 5)
    UIList.VerticalAlignment = Enum.VerticalAlignment.Bottom
    UIList.Parent = NotificationHolder

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "Window"
    MainFrame.Size = UDim2.new(0, 80, 0, 45)
    MainFrame.Position = UDim2.new(0.5, -40, 0.5, -22)
    MainFrame.BackgroundColor3 = Theme.Background
    MainFrame.BackgroundTransparency = 1
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Theme.Stroke
    MainStroke.Thickness = 1
    MainStroke.Parent = MainFrame

    TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 650, 0, 420),
        Position = UDim2.new(0.5, -325, 0.5, -210),
        BackgroundTransparency = 0.05
    }):Play()

    local MainCorner = Instance.new("UICorner", MainFrame)
    MainCorner.CornerRadius = Theme.CornerRadius

    local Sidebar = Instance.new("Frame")
    Sidebar.Size = UDim2.new(0, 180, 1, 0)
    Sidebar.BackgroundColor3 = Theme.Sidebar
    Sidebar.BackgroundTransparency = 0
    Sidebar.Parent = MainFrame
    Instance.new("UICorner", Sidebar).CornerRadius = Theme.CornerRadius
    
    local SidebarFix = Instance.new("Frame")
    SidebarFix.Size = UDim2.new(0, 10, 1, 0)
    SidebarFix.Position = UDim2.new(1, -10, 0, 0)
    SidebarFix.BackgroundColor3 = Theme.Sidebar
    SidebarFix.BorderSizePixel = 0
    SidebarFix.Parent = Sidebar
    
    local SidebarGradient = Instance.new("UIGradient")
    SidebarGradient.Rotation = 45
    SidebarGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200))
    }
    SidebarGradient.Parent = Sidebar

    local DragZone = Instance.new("Frame")
    DragZone.Size = UDim2.new(1, 0, 0, 40)
    DragZone.BackgroundTransparency = 1
    DragZone.Parent = MainFrame

    local Dragging, DragInput, DragStart, StartPos
    DragZone.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Dragging = true
            DragStart = input.Position
            StartPos = MainFrame.Position
        end
    end)
    DragZone.InputEnded:Connect(function(input)
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
        Btn.MouseEnter:Connect(function() PlayAudio("Hover") end)
        Btn.MouseButton1Click:Connect(function() PlayAudio("Click") end)
        return Btn
    end

    local CloseBtn = CreateDot(Color3.fromRGB(255, 95, 87), 0)
    local HideBtn = CreateDot(Color3.fromRGB(255, 189, 46), 20)
    local OpenBtn = CreateDot(Color3.fromRGB(40, 200, 64), 40)

    --// CLOSE CONFIRMATION //
    local function ShowCloseConfirmation()
        local ConfirmBlur = Instance.new("Frame")
        ConfirmBlur.Size = UDim2.new(1,0,1,0)
        ConfirmBlur.BackgroundColor3 = Color3.fromRGB(0,0,0)
        ConfirmBlur.BackgroundTransparency = 1
        ConfirmBlur.ZIndex = 10
        ConfirmBlur.Parent = ScreenGui
        TweenService:Create(ConfirmBlur, TweenInfo.new(0.3), {BackgroundTransparency = 0.6}):Play()

        local AlertFrame = Instance.new("Frame")
        AlertFrame.Size = UDim2.new(0,0,0,0)
        AlertFrame.Position = UDim2.new(0.5,0,0.5,0)
        AlertFrame.BackgroundColor3 = Theme.Background
        AlertFrame.ClipsDescendants = true
        AlertFrame.ZIndex = 11
        AlertFrame.Parent = ConfirmBlur
        Instance.new("UICorner", AlertFrame).CornerRadius = Theme.CornerRadius
        Instance.new("UIStroke", AlertFrame).Color = Theme.Stroke

        local AlertTitle = Instance.new("TextLabel")
        AlertTitle.Text = "Exit Script?"
        AlertTitle.Size = UDim2.new(1,0,0,30)
        AlertTitle.Position = UDim2.new(0,0,0,15)
        AlertTitle.BackgroundTransparency = 1
        AlertTitle.TextColor3 = Theme.Text
        AlertTitle.Font = Enum.Font.GothamBold
        AlertTitle.TextSize = 18
        AlertTitle.ZIndex = 12
        AlertTitle.Parent = AlertFrame

        local AlertMsg = Instance.new("TextLabel")
        AlertMsg.Text = "Are you sure you want to close the menu?"
        AlertMsg.Size = UDim2.new(1,0,0,20)
        AlertMsg.Position = UDim2.new(0,0,0,45)
        AlertMsg.BackgroundTransparency = 1
        AlertMsg.TextColor3 = Theme.TextDim
        AlertMsg.Font = Enum.Font.Gotham
        AlertMsg.TextSize = 14
        AlertMsg.ZIndex = 12
        AlertMsg.Parent = AlertFrame

        local YesBtn = Instance.new("TextButton")
        YesBtn.Text = "Yes"
        YesBtn.Size = UDim2.new(0.4, 0, 0, 35)
        YesBtn.Position = UDim2.new(0.05, 0, 0.7, 0)
        YesBtn.BackgroundColor3 = Theme.Destructive
        YesBtn.TextColor3 = Color3.new(1,1,1)
        YesBtn.Font = Enum.Font.GothamBold
        YesBtn.TextSize = 14
        YesBtn.ZIndex = 12
        YesBtn.Parent = AlertFrame
        Instance.new("UICorner", YesBtn).CornerRadius = UDim.new(0, 8)
        YesBtn.MouseEnter:Connect(function() PlayAudio("Hover") end)

        local NoBtn = Instance.new("TextButton")
        NoBtn.Text = "No"
        NoBtn.Size = UDim2.new(0.4, 0, 0, 35)
        NoBtn.Position = UDim2.new(0.55, 0, 0.7, 0)
        NoBtn.BackgroundColor3 = Theme.Sidebar
        NoBtn.TextColor3 = Theme.Text
        NoBtn.Font = Enum.Font.GothamBold
        NoBtn.TextSize = 14
        NoBtn.ZIndex = 12
        NoBtn.Parent = AlertFrame
        Instance.new("UICorner", NoBtn).CornerRadius = UDim.new(0, 8)
        NoBtn.MouseEnter:Connect(function() PlayAudio("Hover") end)

        TweenService:Create(AlertFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back), {Size = UDim2.new(0, 280, 0, 160), Position = UDim2.new(0.5, -140, 0.5, -80)}):Play()

        YesBtn.MouseButton1Click:Connect(function()
            PlayAudio("Click")
            TweenService:Create(MainFrame, TweenInfo.new(0.3), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}):Play()
            TweenService:Create(AlertFrame, TweenInfo.new(0.3), {Size = UDim2.new(0,0,0,0), BackgroundTransparency = 1}):Play()
            TweenService:Create(ConfirmBlur, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.wait(0.3)
            ScreenGui:Destroy()
        end)

        NoBtn.MouseButton1Click:Connect(function()
            PlayAudio("Click")
            TweenService:Create(AlertFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0,0,0,0), Position = UDim2.new(0.5,0,0.5,0)}):Play()
            TweenService:Create(ConfirmBlur, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            task.wait(0.3)
            ConfirmBlur:Destroy()
        end)
    end

    CloseBtn.MouseButton1Click:Connect(ShowCloseConfirmation)
    
    HideBtn.MouseButton1Click:Connect(function()
        IsMenuOpen = false
        TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 80, 0, 45)}):Play()
        Sidebar.Visible = false
        ContentPageHolder.Visible = false
    end)

    OpenBtn.MouseButton1Click:Connect(function()
        IsMenuOpen = true
        TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = UDim2.new(0, 650, 0, 420)}):Play()
        task.wait(0.1)
        Sidebar.Visible = true
        ContentPageHolder.Visible = true
    end)

    --// TOGGLE UI KEYBIND //
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if IsSettingKeybind then return end 
        
        if input.KeyCode == ToggleKey then
            if IsMenuOpen then
                IsMenuOpen = false
                TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 80, 0, 45)}):Play()
                Sidebar.Visible = false
                ContentPageHolder.Visible = false
            else
                IsMenuOpen = true
                TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = UDim2.new(0, 650, 0, 420)}):Play()
                task.wait(0.1)
                Sidebar.Visible = true
                ContentPageHolder.Visible = true
            end
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

    --// PROFILE SECTION
    local ProfileFrame = Instance.new("Frame")
    ProfileFrame.Name = "ProfileFrame"
    ProfileFrame.Size = UDim2.new(1, -24, 0, 50)
    ProfileFrame.Position = UDim2.new(0, 12, 1, -62)
    ProfileFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    ProfileFrame.BackgroundTransparency = 0.6
    ProfileFrame.Parent = Sidebar
    Instance.new("UICorner", ProfileFrame).CornerRadius = UDim.new(0, 10)
    local ProfileStroke = Instance.new("UIStroke", ProfileFrame)
    ProfileStroke.Color = Theme.Stroke
    ProfileStroke.Transparency = 0.5

    local ProfileImage = Instance.new("ImageLabel")
    ProfileImage.Name = "Avatar"
    ProfileImage.Size = UDim2.new(0, 36, 0, 36)
    ProfileImage.Position = UDim2.new(0, 7, 0.5, -18)
    ProfileImage.BackgroundTransparency = 1
    ProfileImage.Image = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    ProfileImage.Parent = ProfileFrame
    Instance.new("UICorner", ProfileImage).CornerRadius = UDim.new(1, 0)
    
    local OnlineDot = Instance.new("Frame")
    OnlineDot.Size = UDim2.new(0, 10, 0, 10)
    OnlineDot.Position = UDim2.new(0, 34, 0, 26)
    OnlineDot.BackgroundColor3 = Theme.Success
    OnlineDot.BorderSizePixel = 0
    OnlineDot.Parent = ProfileFrame
    Instance.new("UICorner", OnlineDot).CornerRadius = UDim.new(1, 0)
    local DotStroke = Instance.new("UIStroke", OnlineDot)
    DotStroke.Color = Theme.Sidebar
    DotStroke.Thickness = 2

    local DisplayNameLabel = Instance.new("TextLabel")
    DisplayNameLabel.Name = "DName"
    DisplayNameLabel.Size = UDim2.new(1, -50, 0, 18)
    DisplayNameLabel.Position = UDim2.new(0, 50, 0, 8)
    DisplayNameLabel.BackgroundTransparency = 1
    DisplayNameLabel.Text = LocalPlayer.DisplayName
    DisplayNameLabel.TextColor3 = Theme.Text
    DisplayNameLabel.Font = Enum.Font.GothamBold
    DisplayNameLabel.TextSize = 12
    DisplayNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    DisplayNameLabel.Parent = ProfileFrame

    local UserNameLabel = Instance.new("TextLabel")
    UserNameLabel.Name = "UName"
    UserNameLabel.Size = UDim2.new(1, -50, 0, 14)
    UserNameLabel.Position = UDim2.new(0, 50, 0, 26)
    UserNameLabel.BackgroundTransparency = 1
    UserNameLabel.Text = "@" .. LocalPlayer.Name
    UserNameLabel.TextColor3 = Theme.TextDim
    UserNameLabel.Font = Enum.Font.Gotham
    UserNameLabel.TextSize = 11
    UserNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    UserNameLabel.Parent = ProfileFrame

    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Size = UDim2.new(1, -20, 1, -160)
    TabContainer.Position = UDim2.new(0, 10, 0, 90)
    TabContainer.BackgroundTransparency = 1
    TabContainer.ScrollBarThickness = 0
    TabContainer.Parent = Sidebar
    Instance.new("UIListLayout", TabContainer).Padding = UDim.new(0, 5)

    local Tabs = {}
    local FirstTab = true
    function Tabs:CreateTab(Name, Icon)
        local TabData = {}
        local TabBtn = Instance.new("TextButton")
        TabBtn.Size = UDim2.new(1, 0, 0, 36)
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = "    " .. (Icon or "") .. "  " .. Name
        TabBtn.TextColor3 = Theme.TextDim
        TabBtn.Font = Enum.Font.GothamMedium
        TabBtn.TextSize = 14
        TabBtn.TextXAlignment = Enum.TextXAlignment.Left
        TabBtn.Parent = TabContainer
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 8)
        
        TabBtn.MouseEnter:Connect(function() PlayAudio("Hover") end)
        
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
            PlayAudio("Click")
            for _, c in pairs(TabContainer:GetChildren()) do 
                if c:IsA("TextButton") then 
                    TweenService:Create(c, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextColor3 = Theme.TextDim}):Play()
                end 
            end
            for _, c in pairs(ContentPageHolder:GetChildren()) do if c:IsA("ScrollingFrame") then c.Visible = false end end
            Page.Visible = true
            TweenService:Create(TabBtn, TweenInfo.new(0.3), {BackgroundTransparency = 0.85, TextColor3 = Theme.Text}):Play()
            TabBtn.BackgroundColor3 = Theme.Text
        end
        TabBtn.MouseButton1Click:Connect(Activate)
        if FirstTab then Activate() FirstTab = false end

        function TabData:CreateToggle(Text, Callback, Default)
            local ToggleFrame = Instance.new("Frame", Page)
            ToggleFrame.Size = UDim2.new(1, 0, 0, 44)
            ToggleFrame.BackgroundColor3 = Theme.Sidebar
            ToggleFrame.BackgroundTransparency = 0.5
            Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 10)
            local ToggleStroke = Instance.new("UIStroke", ToggleFrame)
            ToggleStroke.Color = Theme.Stroke
            ToggleStroke.Transparency = 0.5
            
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
            SwitchBg.BackgroundColor3 = Default and Theme.Accent or Color3.fromRGB(60, 60, 70)
            Instance.new("UICorner", SwitchBg).CornerRadius = UDim.new(1, 0)

            local SwitchCircle = Instance.new("Frame", SwitchBg)
            SwitchCircle.Size = UDim2.new(0, 20, 0, 20)
            SwitchCircle.Position = Default and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
            SwitchCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", SwitchCircle).CornerRadius = UDim.new(1, 0)

            local Toggled = Default or false
            local Trigger = Instance.new("TextButton", ToggleFrame)
            Trigger.Size = UDim2.new(1, 0, 1, 0)
            Trigger.BackgroundTransparency = 1
            Trigger.Text = ""
            Trigger.MouseEnter:Connect(function() PlayAudio("Hover") end)

            Trigger.MouseButton1Click:Connect(function()
                PlayAudio("Click")
                Toggled = not Toggled
                TweenService:Create(SwitchBg, TweenInfo.new(0.3), {BackgroundColor3 = Toggled and Theme.Accent or Color3.fromRGB(60, 60, 70)}):Play()
                TweenService:Create(SwitchCircle, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = Toggled and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)}):Play()
                Library:Notify("Toggle Update", Text .. " has been " .. (Toggled and "Enabled" or "Disabled"), 2)
                Callback(Toggled)
            end)
        end

        function TabData:CreateSlider(Text, Min, Max, Default, Callback)
            local SliderFrame = Instance.new("Frame", Page)
            SliderFrame.Size = UDim2.new(1, 0, 0, 55)
            SliderFrame.BackgroundColor3 = Theme.Sidebar
            SliderFrame.BackgroundTransparency = 0.5
            Instance.new("UICorner", SliderFrame).CornerRadius = UDim.new(0, 10)
            local SliderStroke = Instance.new("UIStroke", SliderFrame)
            SliderStroke.Color = Theme.Stroke
            SliderStroke.Transparency = 0.5

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
            SliderBar.Position = UDim2.new(0, 20, 0, 38)
            SliderBar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            Instance.new("UICorner", SliderBar)

            local SliderFill = Instance.new("Frame", SliderBar)
            SliderFill.Size = UDim2.new((Default - Min) / (Max - Min), 0, 1, 0)
            SliderFill.BackgroundColor3 = Theme.Accent
            Instance.new("UICorner", SliderFill)
            
            local SliderBtn = Instance.new("Frame", SliderFill)
            SliderBtn.Size = UDim2.new(0, 12, 0, 12)
            SliderBtn.Position = UDim2.new(1, -6, 0.5, -6)
            SliderBtn.BackgroundColor3 = Color3.new(1,1,1)
            Instance.new("UICorner", SliderBtn).CornerRadius = UDim.new(1, 0)

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
            ButtonFrame.BackgroundColor3 = Theme.Accent
            ButtonFrame.BackgroundTransparency = 0.2
            Instance.new("UICorner", ButtonFrame).CornerRadius = UDim.new(0, 10)
            
            local Gradient = Instance.new("UIGradient")
            Gradient.Rotation = 90
            Gradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
                ColorSequenceKeypoint.new(1, Theme.Accent)
            }
            Gradient.Transparency = NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0.7),
                NumberSequenceKeypoint.new(1, 0.1)
            }
            Gradient.Parent = ButtonFrame
            
            local BtnStroke = Instance.new("UIStroke", ButtonFrame)
            BtnStroke.Color = Color3.fromRGB(255,255,255)
            BtnStroke.Transparency = 0.6
            BtnStroke.Thickness = 1

            local Btn = Instance.new("TextButton", ButtonFrame)
            Btn.Size = UDim2.new(1, 0, 1, 0)
            Btn.BackgroundTransparency = 1
            Btn.Text = Text
            Btn.TextColor3 = Color3.fromRGB(255,255,255)
            Btn.Font = Enum.Font.GothamBold
            Btn.TextSize = 14
            Btn.MouseEnter:Connect(function() PlayAudio("Hover") end)

            Btn.MouseButton1Click:Connect(function()
                PlayAudio("Click")
                Library:Notify("Action", Text .. " Triggered", 2)
                Callback()
            end)
            return Btn
        end
        return TabData
    end
    return Tabs
end

--// INIT
local Window = Library:Init()
local MainTab = Window:CreateTab("Main", "🏠")

MainTab:CreateToggle("Enable WalkSpeed", function(val) WalkSpeedEnabled = val end, false)
MainTab:CreateSlider("WalkSpeed Value", 16, 150, 24, function(val) WalkSpeedValue = val end)
MainTab:CreateToggle("Noclip", function(val) 
    NoclipEnabled = val
    ToggleNoclipSystem(val)
end, false)
MainTab:CreateToggle("Auto Skillcheck", function(val)
    AutoSkillCheckEnabled = val
end, false)

local VisualsTab = Window:CreateTab("Visuals", "👁️")
VisualsTab:CreateToggle("ESP Twisteds", function(val) ESP_Settings.Twisteds.Enabled = val end, false)
VisualsTab:CreateToggle("ESP Generators", function(val) ESP_Settings.Generators.Enabled = val end, false)
VisualsTab:CreateToggle("ESP Items", function(val) ESP_Settings.Items.Enabled = val end, false)
VisualsTab:CreateToggle("ESP Players", function(val) ESP_Settings.Players.Enabled = val end, false)

local TeleportTab = Window:CreateTab("Teleports", "✈️")
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

TeleportTab:CreateToggle("Auto TP Elevator", function(val)
    AutoEscapeEnabled = val
end, false)

TeleportTab:CreateButton("TP to Uncompleted Machine", function()
    pcall(function()
        local currentRoom = Workspace:FindFirstChild("CurrentRoom")
        if not currentRoom then return end
        
        local generatorsFolder = nil
        for _, child in pairs(currentRoom:GetChildren()) do
            generatorsFolder = child:FindFirstChild("Generators")
            if generatorsFolder then break end
        end
        if not generatorsFolder then return end
        
        local targetGenerator = nil
        for _, gen in pairs(generatorsFolder:GetChildren()) do
            local stats = gen:FindFirstChild("Stats")
            if stats then
                local completedVal = stats:FindFirstChild("Completed")
                if completedVal and completedVal.Value == false then
                    targetGenerator = gen
                    break
                end
            end
        end
        
        if targetGenerator and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local tpPosFolder = targetGenerator:FindFirstChild("TeleportPositions")
            local targetCFrame = nil
            if tpPosFolder and #tpPosFolder:GetChildren() > 0 then
                targetCFrame = tpPosFolder:GetChildren()[1].CFrame
            else
                targetCFrame = targetGenerator:GetPivot()
            end
            if targetCFrame then
                LocalPlayer.Character.HumanoidRootPart.CFrame = targetCFrame + Vector3.new(0, 3, 0)
            end
        end
    end)
end)

local FarmingTab = Window:CreateTab("Farming", "🎒")

local function AutoCollectItem(targetName)
    local room = Workspace:FindFirstChild("CurrentRoom")
    if not room then return end
    
    local items = {}
    for _, child in pairs(room:GetChildren()) do
        local itemFolder = child:FindFirstChild("Items")
        if itemFolder then
            for _, v in pairs(itemFolder:GetChildren()) do
                if v.Name == targetName or (targetName == "Research" and v.Name:match("Research")) then
                    table.insert(items, v)
                end
            end
        end
        if child.Name == targetName or (targetName == "Research" and child.Name:match("Research")) then
             table.insert(items, child)
        end
    end

    if #items == 0 then
        Library:Notify("Auto Collect", "No " .. targetName .. "s found nearby!", 3)
        return
    end

    Library:Notify("Auto Collect", "Collecting " .. #items .. " " .. targetName .. "s...", 3)

    for _, item in pairs(items) do
        if item and item.Parent and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local part = item:IsA("Model") and item.PrimaryPart or item:FindFirstChild("Handle") or item:FindFirstChildOfClass("BasePart")
            local prompt = item:FindFirstChild("ProximityPrompt", true)
            
            if part and prompt then
                LocalPlayer.Character.HumanoidRootPart.CFrame = part.CFrame + Vector3.new(0, 3, 0)
                task.wait(0.25)
                
                local start = tick()
                repeat
                    if item.Parent == nil then break end
                    LocalPlayer.Character.HumanoidRootPart.CFrame = part.CFrame 
                    
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    else
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait()
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end
                    task.wait(0.1)
                until tick() - start > 2 or item.Parent == nil
            end
        end
    end
    Library:Notify("Auto Collect", "Collection Complete.", 3)
end

FarmingTab:CreateButton("Auto Collect Tapes", function()
    AutoCollectItem("Tape")
end)

FarmingTab:CreateButton("Auto Collect Research", function()
    AutoCollectItem("Research")
end)

local StuffTab = Window:CreateTab("Stuff", "⚙️")
StuffTab:CreateButton("Force Reset", function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.Health = 0
    end
end)

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
end, false)

local SettingsTab = Window:CreateTab("Settings", "🛠️")

SettingsTab:CreateToggle("Enable UI Sounds", function(val)
    SoundEnabled = val
end, true)

local KeybindButton
KeybindButton = SettingsTab:CreateButton("Menu Keybind: LeftControl", function()
    KeybindButton.Text = "Press any key..."
    IsSettingKeybind = true 
    local InputConnection
    InputConnection = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            ToggleKey = input.KeyCode
            KeybindButton.Text = "Menu Keybind: " .. input.KeyCode.Name
            Library:Notify("Settings", "Keybind set to " .. input.KeyCode.Name, 2)
            task.wait(0.2) 
            IsSettingKeybind = false 
            InputConnection:Disconnect()
        end
    end)
end)

print("Poorly Scripted v6.7 - Perfected Health ESP")
