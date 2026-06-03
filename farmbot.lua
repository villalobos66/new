local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Variables principales
local FarmEnabled = false
local chasingActive = false
local chaseConnection = nil
local currentChaseTarget = nil
local targetPlayer = nil
local exactTargetName = ""

-- Variables para FARM
local DISTANCIA_ADELANTE = 5  -- Distancia adelante del enemigo (studs)

-- ==================== ANTI-RAGDOLL INTEGRADO ====================
local antiRagdollActive = false
local heartbeatConnection = nil
local currentCharacter = nil
local humanoid = nil
local rootPart = nil

-- Almacén para objetos modificados
local modifiedObjects = {
    constraints = {},
    animations = {},
    scripts = {},
}

-- Limpiar conexiones anti-ragdoll
local function disconnectAntiRagdoll()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
end

-- Restaurar todo
local function restoreAll()
    if not currentCharacter then return end
    
    pcall(function()
        for _, constraint in ipairs(modifiedObjects.constraints) do
            if constraint then
                pcall(function()
                    if constraint:FindFirstChild("Enabled") then
                        constraint.Enabled = true
                    elseif constraint.Parent ~= currentCharacter then
                        constraint.Parent = currentCharacter
                    end
                end)
            end
        end
        
        for _, animTrack in ipairs(modifiedObjects.animations) do
            pcall(function() if animTrack then animTrack:Play() end end)
        end
        
        for _, scriptObj in ipairs(modifiedObjects.scripts) do
            pcall(function()
                if scriptObj and scriptObj:IsA("Script") then
                    scriptObj.Disabled = false
                end
            end)
        end
        
        modifiedObjects.constraints = {}
        modifiedObjects.animations = {}
        modifiedObjects.scripts = {}
    end)
    
    if humanoid then
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
    end
end

-- Protección anti-ragdoll (sin bug de movimiento)
local function applyProtections()
    if not antiRagdollActive then return end
    if not currentCharacter or not humanoid or not humanoid.Parent then return end
    
    if not rootPart or not rootPart.Parent then
        rootPart = currentCharacter:FindFirstChild("HumanoidRootPart") or 
                   currentCharacter:FindFirstChild("Torso") or 
                   currentCharacter:FindFirstChild("UpperTorso")
        if not rootPart then return end
    end
    
    pcall(function()
        local currentState = humanoid:GetState()
        local badStates = {
            [Enum.HumanoidStateType.Physics] = true,
            [Enum.HumanoidStateType.FallingDown] = true,
            [Enum.HumanoidStateType.GettingUp] = true,
            [Enum.HumanoidStateType.Dead] = true,
        }
        
        if badStates[currentState] then
            local originalCFrame = rootPart.CFrame
            
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
            
            task.wait(0.01)
            if rootPart and rootPart.Parent then
                rootPart.CFrame = originalCFrame
                rootPart.Velocity = Vector3.zero
                rootPart.RotVelocity = Vector3.zero
            end
            
            for _, part in ipairs(currentCharacter:GetChildren()) do
                if part:IsA("BasePart") and part ~= rootPart then
                    pcall(function()
                        part.Velocity = Vector3.zero
                        part.RotVelocity = Vector3.zero
                    end)
                end
            end
        end
        
        humanoid.PlatformStand = false
        humanoid.AutoRotate = true
        
        -- Mover constraints temporalmente
        local tempFolder = player:FindFirstChild("TempAntiRagdoll")
        if not tempFolder then
            tempFolder = Instance.new("Folder")
            tempFolder.Name = "TempAntiRagdoll"
            tempFolder.Parent = player
        end
        
        for _, constraint in ipairs(currentCharacter:GetDescendants()) do
            if constraint:IsA("Constraint") then
                local alreadySaved = false
                for _, saved in ipairs(modifiedObjects.constraints) do
                    if saved == constraint then 
                        alreadySaved = true 
                        break 
                    end
                end
                if not alreadySaved then
                    table.insert(modifiedObjects.constraints, constraint)
                end
                constraint.Parent = tempFolder
            end
        end

        -- Detener animaciones malas
        if humanoid.Animator then
            for _, track in ipairs(humanoid.Animator:GetPlayingAnimationTracks()) do
                local animId = track.Animation.AnimationId:lower()
                local shouldStop = false
                for _, keyword in ipairs({"ragdoll", "knock", "stun", "fall", "down", "hit", "getup", "knockout"}) do
                    if animId:find(keyword) then
                        shouldStop = true
                        break
                    end
                end
                if shouldStop then
                    local alreadySaved = false
                    for _, saved in ipairs(modifiedObjects.animations) do
                        if saved == track then
                            alreadySaved = true
                            break
                        end
                    end
                    if not alreadySaved then
                        table.insert(modifiedObjects.animations, track)
                    end
                    track:Stop()
                end
            end
        end

        -- Deshabilitar scripts de ragdoll
        for _, scriptObj in ipairs(currentCharacter:GetDescendants()) do
            if scriptObj:IsA("Script") then
                local nameLower = scriptObj.Name:lower()
                if nameLower:find("ragdoll") or nameLower:find("stun") or nameLower:find("knock") then
                    local alreadySaved = false
                    for _, saved in ipairs(modifiedObjects.scripts) do
                        if saved == scriptObj then
                            alreadySaved = true
                            break
                        end
                    end
                    if not alreadySaved then
                        table.insert(modifiedObjects.scripts, scriptObj)
                    end
                    scriptObj.Disabled = true
                end
            end
        end
    end)
end

local function startAntiRagdoll()
    if heartbeatConnection then
        disconnectAntiRagdoll()
    end
    antiRagdollActive = true
    heartbeatConnection = RunService.RenderStepped:Connect(applyProtections)
end

local function stopAntiRagdoll()
    antiRagdollActive = false
    disconnectAntiRagdoll()
    restoreAll()
end

-- Manejo de personaje para anti-ragdoll
local function onCharacterAdded(newChar)
    currentCharacter = newChar
    humanoid = currentCharacter:WaitForChild("Humanoid", 10)
    rootPart = currentCharacter:FindFirstChild("HumanoidRootPart") or 
               currentCharacter:FindFirstChild("Torso") or 
               currentCharacter:FindFirstChild("UpperTorso")
    
    modifiedObjects.constraints = {}
    modifiedObjects.animations = {}
    modifiedObjects.scripts = {}
    
    if FarmEnabled then
        startAntiRagdoll()
    end
end

player.CharacterAdded:Connect(onCharacterAdded)

if player.Character then
    onCharacterAdded(player.Character)
end

-- ==================== FUNCIONES DE FARM ====================
local PROHIBITED_USERS = {
    "Crxsyx", "LaCoquette6_2", "dewn_sz", "KayKayRirisangel", "Sianq", 
    "nadmire_JL", "Fyro_190", "Msky_nlh", "Zdiogobreno042", "diogobreno0421",
    "Ikaris_BR", "rosado289", "grancheroka_br", "tokyo", "xxdeidaraxx50",
    "ShingekiNoKyojin_17", "Gatitblox", "mmelii_rdz", "darkissoez",
    "darkissoez1", "darkissoez2", "darkissoez3", "darkissoez4", "darkissoez5",
    "darkissoez6", "darkissoez7", "darkissoez8", "darkissoez9", "darkissoez10",
    "darkissoez11", "darkissoez12", "darkissoez13", "darkissoez14", "darkissoez15",
    "darkissoez16", "darkissoez17", "botfuerte1", "botfuerte2", "botfuerte3",
    "botfuerte4", "botfuerte5", "botfuerte6", "botfuerte7", "botfuerte8",
    "botfuerte9", "botfuerte10", "botfuerte11", "botfuerte12", "botfuerte13",
    "botfuerte14", "bloodalt2020", "crxsyx121"
}

local function isPlayerProhibited(playerObj)
    if not playerObj then return false end
    local playerNameLower = playerObj.Name:lower()
    local displayNameLower = playerObj.DisplayName:lower()
    for _, prohibitedName in ipairs(PROHIBITED_USERS) do
        local prohibitedLower = prohibitedName:lower()
        if playerNameLower == prohibitedLower or displayNameLower == prohibitedLower then
            return true
        end
    end
    return false
end

local function findPlayerByPartialName(inputText)
    if inputText == "" or inputText:lower() == "todos" or inputText:lower() == "all" then
        return nil, "TODOS"
    end
    local searchText = inputText:lower():gsub("%s+", "")
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and not isPlayerProhibited(p) then
            if p.Name:lower() == searchText then return p, p.Name end
            if p.DisplayName:lower() == searchText then return p, p.DisplayName end
        end
    end
    if #searchText >= 3 then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and not isPlayerProhibited(p) then
                if p.Name:lower():sub(1, #searchText) == searchText then return p, p.Name end
                if p.DisplayName:lower():sub(1, #searchText) == searchText then return p, p.DisplayName end
            end
        end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and not isPlayerProhibited(p) then
                if p.Name:lower():find(searchText, 1, true) then return p, p.Name end
                if p.DisplayName:lower():find(searchText, 1, true) then return p, p.DisplayName end
            end
        end
    end
    if #searchText > 0 and #searchText < 3 then return false, "Mínimo 3 letras" end
    return false, "No encontrado"
end

local function isTargetValid(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local char = targetPlayer.Character
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end
    if hum.Health <= 0 then return false end
    return true
end

-- Función de Farm (adelante del enemigo a su misma altura)
local function applyChase(target)
    if not target or not target.Character then return end
    
    local localChar = player.Character
    local targetChar = target.Character
    
    if not localChar or not targetChar then return end
    
    local localHRP = localChar:FindFirstChild("HumanoidRootPart")
    local targetHRP = targetChar:FindFirstChild("HumanoidRootPart")
    local localHumanoid = localChar:FindFirstChild("Humanoid")
    local targetHumanoid = targetChar:FindFirstChild("Humanoid")
    
    if not localHRP or not targetHRP or not localHumanoid or not targetHumanoid then return end
    
    -- Obtener la dirección hacia donde mira el enemigo
    local targetCFrame = targetHRP.CFrame
    local targetLookVector = targetCFrame.LookVector
    
    -- Normalizar el vector horizontal
    targetLookVector = Vector3.new(targetLookVector.X, 0, targetLookVector.Z).Unit
    
    -- Calcular posición adelante del enemigo
    local targetPosition = targetHRP.Position + (targetLookVector * DISTANCIA_ADELANTE)
    
    -- Misma altura que el enemigo
    targetPosition = Vector3.new(
        targetPosition.X,
        targetHRP.Position.Y,
        targetPosition.Z
    )
    
    local chaseSpeed = 3000
    local deltaTime = task.wait() or 0.016
    local distanceToTarget = (targetPosition - localHRP.Position).Magnitude
    
    if distanceToTarget < 3 then
        pcall(function()
            localHRP.CFrame = CFrame.new(targetPosition, targetHRP.Position)
            localHRP.Velocity = Vector3.new(0, 0, 0)
            localHRP.RotVelocity = Vector3.new(0, 0, 0)
        end)
    else
        local direction = (targetPosition - localHRP.Position).Unit
        local newPosition = localHRP.Position + direction * chaseSpeed * deltaTime
        
        newPosition = Vector3.new(
            newPosition.X,
            targetHRP.Position.Y,
            newPosition.Z
        )
        
        pcall(function()
            localHRP.CFrame = CFrame.new(newPosition, targetHRP.Position)
            localHRP.Velocity = Vector3.new(0, 0, 0)
            localHRP.RotVelocity = Vector3.new(0, 0, 0)
        end)
    end
    
    currentChaseTarget = target
end

local function stopFarm()
    if chaseConnection then
        chaseConnection:Disconnect()
        chaseConnection = nil
    end
    currentChaseTarget = nil
    chasingActive = false
end

local function startFarm(initialTarget)
    if chasingActive then stopFarm() end
    if not initialTarget then return end
    if not isTargetValid(initialTarget) then return end
    
    chasingActive = true
    
    chaseConnection = RunService.Heartbeat:Connect(function()
        if not FarmEnabled then
            stopFarm()
            return
        end
        
        local localChar = player.Character
        if not localChar then
            stopFarm()
            return
        end
        
        local target = currentChaseTarget or initialTarget
        local targetValid = target and isTargetValid(target)
        
        if targetValid then
            applyChase(target)
        else
            stopFarm()
        end
    end)
end

-- ==================== GUI ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FarmGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 210, 0, 140)
Frame.Position = UDim2.new(0.5, -105, 0.5, -70)
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.BorderSizePixel = 0
Frame.BackgroundTransparency = 0.05
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = Frame

-- Barra de título para arrastrar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 28)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = Frame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0, 8, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Farm"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- Botón de cerrar
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -28, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

-- Botón FARM (Encender/Apagar farm + anti-ragdoll)
local farmBtn = Instance.new("TextButton")
farmBtn.Size = UDim2.new(0.8, 0, 0, 28)
farmBtn.Position = UDim2.new(0.1, 0, 0.23, 0)
farmBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
farmBtn.Text = "FARM: OFF"
farmBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
farmBtn.Font = Enum.Font.GothamBold
farmBtn.TextSize = 12
farmBtn.Parent = Frame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 7)
btnCorner.Parent = farmBtn

-- Label objetivo
local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.new(0.8, 0, 0, 14)
targetLabel.Position = UDim2.new(0.1, 0, 0.5, 0)
targetLabel.BackgroundTransparency = 1
targetLabel.Text = "Objetivo:"
targetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
targetLabel.Font = Enum.Font.Gotham
targetLabel.TextSize = 11
targetLabel.TextXAlignment = Enum.TextXAlignment.Left
targetLabel.Parent = Frame

-- Caja de texto para objetivo
local targetBox = Instance.new("TextBox")
targetBox.Size = UDim2.new(0.8, 0, 0, 25)
targetBox.Position = UDim2.new(0.1, 0, 0.57, 0)
targetBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
targetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
targetBox.Font = Enum.Font.Gotham
targetBox.TextSize = 12
targetBox.PlaceholderText = "Nombre y Enter"
targetBox.Text = ""
targetBox.Parent = Frame

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = targetBox

-- Estado del objetivo
local targetStatus = Instance.new("TextLabel")
targetStatus.Size = UDim2.new(0.8, 0, 0, 14)
targetStatus.Position = UDim2.new(0.1, 0, 0.75, 0)
targetStatus.BackgroundTransparency = 1
targetStatus.Text = "Objetivo: NINGUNO"
targetStatus.TextColor3 = Color3.fromRGB(255, 150, 150)
targetStatus.Font = Enum.Font.Gotham
targetStatus.TextSize = 10
targetStatus.TextXAlignment = Enum.TextXAlignment.Left
targetStatus.Parent = Frame

-- Sistema de arrastre
local dragging = false
local dragStart = nil
local startPos = nil

local function startDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position
    end
end

local function updateDrag(input)
    if dragging and dragStart then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end

TitleBar.InputBegan:Connect(startDrag)
TitleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        dragStart = nil
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    if chaseConnection then chaseConnection:Disconnect() end
    stopAntiRagdoll()
    Frame:Destroy()
    ScreenGui:Destroy()
end)

-- Actualizar estado del objetivo
local function updateTargetStatus()
    if targetPlayer then
        targetStatus.Text = "✓ " .. exactTargetName
        targetStatus.TextColor3 = Color3.fromRGB(80, 255, 80)
    else
        targetStatus.Text = "✗ NINGUNO (todos)"
        targetStatus.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
end

-- Búsqueda de objetivo
local function searchAndSetTarget()
    local searchText = targetBox.Text:gsub("%s+", "")
    local foundPlayer, resultName = findPlayerByPartialName(searchText)
    
    if foundPlayer then
        targetPlayer = foundPlayer
        exactTargetName = resultName
        updateTargetStatus()
        
        if FarmEnabled and chasingActive then
            stopFarm()
            if isTargetValid(targetPlayer) then
                startFarm(targetPlayer)
            end
        end
    elseif foundPlayer == nil then
        targetPlayer = nil
        exactTargetName = ""
        updateTargetStatus()
        
        if FarmEnabled and chasingActive then
            stopFarm()
        end
    else
        targetStatus.Text = "❌ " .. resultName
        targetStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
        task.wait(2)
        updateTargetStatus()
    end
end

targetBox.FocusLost:Connect(function(enterPressed) 
    if enterPressed then searchAndSetTarget() end 
end)

-- TOGGLE FARM
local function toggleFarm()
    FarmEnabled = not FarmEnabled
    
    if FarmEnabled then
        farmBtn.Text = "FARM: ON"
        farmBtn.TextColor3 = Color3.fromRGB(80, 255, 80)
        farmBtn.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
        
        startAntiRagdoll()
        
        if targetPlayer and isTargetValid(targetPlayer) then
            startFarm(targetPlayer)
        end
        print("🌾 FARM ACTIVADO - Adelante del enemigo")
    else
        farmBtn.Text = "FARM: OFF"
        farmBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
        farmBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        
        stopAntiRagdoll()
        stopFarm()
        print("🌾 FARM DESACTIVADO")
    end
end

farmBtn.MouseButton1Click:Connect(toggleFarm)

-- Tecla E
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then
        toggleFarm()
    end
end)

print("=== Sistema de Farm Cargado ===")
print("✅ Posición: ADELANTE del enemigo")
print("✅ Misma altura que el enemigo")
print("✅ Velocidad: 3000")
print("✅ Tecla E: Activar/Desactivar Farm")
