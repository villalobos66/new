local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

do
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")

    local LocalPlayer = Players.LocalPlayer
    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Humanoid.RootPart

    local VerticalOffset = Vector3.new(0, -6000, 0)
    local RotationCFrame = CFrame.Angles(0, 0, math.rad(180))

    local LastRootCFrame = RootPart.CFrame
    local IsEnabled = false
    local Connections = {}
    local RenderSteps = {}
    local NoclipConnection = nil

    local function DisableCollisions()
        if not Character then return end
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    local function EnableCollisions()
        if not Character then return end
        for _, part in ipairs(Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end

    local function Cleanup()
        for _, conn in ipairs(Connections) do
            conn:Disconnect()
        end
        Connections = {}
        for _, step in ipairs(RenderSteps) do
            RunService:UnbindFromRenderStep(step)
        end
        RenderSteps = {}
        
        if NoclipConnection then
            NoclipConnection:Disconnect()
            NoclipConnection = nil
        end
    end

    local function Activate()
        if IsEnabled then return end
        Cleanup()
        IsEnabled = true
        LastRootCFrame = RootPart.CFrame
        
        -- Desactivar colisiones
        DisableCollisions()

        local step1 = "Step1_" .. tick()
        local step2 = "Step2_" .. tick()

        RunService:BindToRenderStep(step1, Enum.RenderPriority.Camera.Value - 5, function()
            if RootPart and IsEnabled then
                RootPart.CFrame = LastRootCFrame
            end
        end)
        table.insert(RenderSteps, step1)

        RunService:BindToRenderStep(step2, Enum.RenderPriority.Camera.Value + 5, function()
            if RootPart and IsEnabled then
                LastRootCFrame = RootPart.CFrame
                local newPosition = RootPart.Position + VerticalOffset
                RootPart.CFrame = CFrame.new(newPosition) * RotationCFrame
                DisableCollisions()
            end
        end)
        table.insert(RenderSteps, step2)

        table.insert(Connections, RunService.PreAnimation:Connect(function()
            if RootPart and IsEnabled then
                RootPart.CFrame = LastRootCFrame
                DisableCollisions()
            end
        end))

        table.insert(Connections, RunService.PostSimulation:Connect(function()
            if RootPart and IsEnabled then
                LastRootCFrame = RootPart.CFrame
                local newPosition = RootPart.Position + VerticalOffset
                RootPart.CFrame = CFrame.new(newPosition) * RotationCFrame
                DisableCollisions()
            end
        end))
        
        -- Noclip continuo SOLO cuando está activado
        NoclipConnection = RunService.Stepped:Connect(function()
            if IsEnabled and Character then
                DisableCollisions()
            end
        end)
    end

    local function Deactivate()
        if not IsEnabled then return end
        IsEnabled = false
        Cleanup()
        
        -- Restaurar colisiones al apagar
        EnableCollisions()
        
        if RootPart then
            RootPart.CFrame = LastRootCFrame
        end
    end

    local function Toggle()
        if IsEnabled then
            Deactivate()
        else
            Activate()
        end
    end

    local function IsActive()
        return IsEnabled
    end

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        RootPart = Humanoid.RootPart
        LastRootCFrame = RootPart.CFrame
        
        if IsEnabled then
            task.wait(0.1)
            IsEnabled = false
            Activate()
        end
    end)

    _G.ToggleInvis = Toggle
    _G.IsInvisActive = IsActive
end

-- INTERFAZ (sin cambios, igual que el original)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InvisHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player.PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 60, 0, 30)
MainFrame.Position = UDim2.new(0.5, -30, 0.5, -15)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.Position = UDim2.new(0, 0, 0, 0)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
ToggleBtn.Text = "OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 10
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = MainFrame

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 5)
BtnCorner.Parent = ToggleBtn

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 15)
TopBar.Position = UDim2.new(0, 0, 0, -15)
TopBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
TopBar.BackgroundTransparency = 0.15
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 5)
TopBarCorner.Parent = TopBar

local function UpdateButton()
    if _G.IsInvisActive and _G.IsInvisActive() then
        ToggleBtn.Text = "ON"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    else
        ToggleBtn.Text = "OFF"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    if _G.ToggleInvis then
        _G.ToggleInvis()
        UpdateButton()
    end
end)

local dragging = false
local dragStart, startPos

TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                     input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.T then
        if _G.ToggleInvis then
            _G.ToggleInvis()
            UpdateButton()
        end
    end
end)

UpdateButton()

game:GetService("Workspace").FallenPartsDestroyHeight = 0/0

print("✅ Invisibilidad + Noclip activado")
