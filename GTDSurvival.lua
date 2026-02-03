--====================================================
-- LOAD SAFETY
--====================================================
if not game:IsLoaded() then
    game.Loaded:Wait()
end

--====================================================
-- SERVICES
--====================================================
local Players = game:GetService("Players")
local RunService = game:IsLoaded() and game:GetService("RunService") or nil
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--====================================================
-- SAFETY CHECKS & STEALTH
--====================================================
local function validateEnvironment()
    if not RunService or not LocalPlayer.Character then
        return false
    end
    
    -- Check for common anti-cheat services
    local acServices = {
        "ScriptContext",
        "ScriptSigningService",
        "NetworkClient",
        "SocialService"
    }
    
    for _, name in ipairs(acServices) do
        if game:GetService(name):GetChildren() and #game:GetService(name):GetChildren() > 0 then
            warn("Potential anti-cheat detected: " .. name)
        end
    end
    
    return true
end

--====================================================
-- ENHANCED UTILITIES
--====================================================
local function safeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("Safe call failed:", result)
    end
    return success, result
end

local function getSafeZone()
    -- Find a safe location far from the map
    local mapCenter = Vector3.new(0, 1000, 0)  -- High above map
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
    raycastParams.FilterDescendantsInstances = {Workspace.Terrain}
    
    local result = Workspace:Raycast(mapCenter, Vector3.new(0, -2000, 0), raycastParams)
    if result then
        return result.Position + Vector3.new(0, 50, 0)
    end
    
    -- Alternative: Check for world boundaries
    local worldRoot = Workspace:FindFirstChild("WorldRoot") or Workspace
    local worldSize = worldRoot:GetExtentsSize()
    return Vector3.new(0, worldSize.Y + 500, 0)
end

--====================================================
-- CONFIGURATION
--====================================================
local SAFE_ZONE_OFFSET = Vector3.new(0, 2000, 0)  -- Far above map
local DECOY_SIZE = Vector3.new(2, 4, 1)  -- Standard player hitbox size
local SMOOTH_FACTOR = 0.25
local MIN_FOLLOW_DISTANCE = 15
local MAX_FOLLOW_DISTANCE = 30

--====================================================
-- STATE MANAGEMENT
--====================================================
local states = {
    ACTIVE = false,
    DECOY = nil,
    REAL_HRP = nil,
    CONNECTION = nil,
    SAFE_POSITION = nil,
    ORIGINAL_PROPERTIES = {}
}

--====================================================
-- MINIMAL UI (LOW PROFILE)
--====================================================
local function createMinimalUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SystemOverlay"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.Size = UDim2.new(0, 100, 0, 40)
    toggleBtn.Position = UDim2.new(1, -110, 0, 10)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    toggleBtn.BorderSizePixel = 1
    toggleBtn.BorderColor3 = Color3.fromRGB(60, 60, 60)
    toggleBtn.Text = "SYSTEM\nOFF"
    toggleBtn.TextColor3 = Color3.new(1, 1, 1)
    toggleBtn.Font = Enum.Font.Gotham
    toggleBtn.TextSize = 12
    toggleBtn.ZIndex = 2
    toggleBtn.Parent = screenGui
    
    -- Add subtle corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = toggleBtn
    
    return toggleBtn
end

--====================================================
-- HITBOX PRESERVATION & DECOY CREATION
--====================================================
local function preserveOriginalProperties(character)
    states.ORIGINAL_PROPERTIES = {}
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp then
        states.ORIGINAL_PROPERTIES.HRP = {
            Position = hrp.Position,
            CFrame = hrp.CFrame,
            CanCollide = hrp.CanCollide,
            Transparency = hrp.Transparency
        }
    end
    
    local hum = character:FindFirstChild("Humanoid")
    if hum then
        states.ORIGINAL_PROPERTIES.HUMANOID = {
            CameraOffset = hum.CameraOffset
        }
    end
end

local function createMobDecoy(originalPosition)
    -- Create a decoy that mimics player hitbox
    local decoy = Instance.new("Part")
    decoy.Name = "NPC_Hitbox"  -- Generic name to avoid detection
    decoy.Size = DECOY_SIZE
    decoy.Transparency = 0.95  -- Nearly invisible but slightly visible
    decoy.Color = Color3.fromRGB(50, 50, 50)
    decoy.Material = EnumMaterial.ForceField
    decoy.CanCollide = true
    decoy.CanTouch = true
    decoy.Anchored = false
    decoy.Position = originalPosition
    decoy.Parent = Workspace
    
    -- Add network ownership to local player for smooth movement
    if decoy:CanSetNetworkOwnership() then
        decoy:SetNetworkOwnership(LocalPlayer)
    end
    
    -- Add subtle visual effect (optional)
    local glow = Instance.new("SurfaceGui", decoy)
    glow.Face = Enum.NormalId.Front
    glow.AlwaysOnTop = true
    
    local frame = Instance.new("Frame", glow)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    frame.BackgroundTransparency = 0.8
    frame.BorderSizePixel = 0
    
    return decoy
end

--====================================================
-- SAFE ZONE TELEPORTATION
--====================================================
local function teleportToSafeZone(character)
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Store safe position
    states.SAFE_POSITION = getSafeZone() + SAFE_ZONE_OFFSET
    
    -- Use multiple methods to ensure safe teleportation
    safeCall(function()
        -- Method 1: Direct CFrame change (fastest)
        hrp.CFrame = CFrame.new(states.SAFE_POSITION)
        
        -- Method 2: Reset velocities
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        
        -- Method 3: Make character temporarily non-collidable
        hrp.CanCollide = false
        
        -- Method 4: Reduce hitbox size temporarily
        hrp.Size = Vector3.new(0.5, 0.5, 0.5)
        
        -- Method 5: Add a forcefield-like effect
        local forcefield = Instance.new("ForceField")
        forcefield.Visible = false
        forcefield.Parent = character
    end)
    
    -- Small delay to ensure teleportation
    task.wait(0.1)
end

--====================================================
-- MOVEMENT HANDLER
--====================================================
local function updateDecoyMovement()
    if not states.DECOY or not states.REAL_HRP then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    -- Get movement input
    local moveDirection = humanoid.MoveDirection
    local currentDecoyPos = states.DECOY.Position
    
    if moveDirection.Magnitude > 0 then
        -- Calculate target position based on movement
        local targetPos = currentDecoyPos + (moveDirection * MIN_FOLLOW_DISTANCE)
        
        -- Smooth movement using lerp
        local smoothedPos = currentDecoyPos:Lerp(targetPos, SMOOTH_FACTOR)
        
        -- Apply movement to decoy
        states.DECOY.CFrame = CFrame.new(smoothedPos)
        
        -- Keep decoy upright
        states.DECOY.Orientation = Vector3.new(0, states.DECOY.Orientation.Y, 0)
    end
    
    -- Ensure real character stays in safe zone
    if states.REAL_HRP then
        states.REAL_HRP.CFrame = CFrame.new(states.SAFE_POSITION)
        states.REAL_HRP.AssemblyLinearVelocity = Vector3.zero
        states.REAL_HRP.AssemblyAngularVelocity = Vector3.zero
    end
end

--====================================================
-- MOB AGGRO MANAGEMENT
--====================================================
local function redirectMobAggro()
    -- This function makes mobs target the decoy instead of the player
    -- It works by making the decoy appear as the primary target
    
    -- Method 1: Make decoy emit "humanoid" signals
    if states.DECOY then
        -- Create a fake humanoid to attract mobs
        local fakeHum = Instance.new("Humanoid")
        fakeHum.Health = 100
        fakeHum.MaxHealth = 100
        fakeHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        fakeHum.Parent = states.DECOY
        
        -- Make decoy appear as a valid target
        states.DECOY.Name = "PlayerHitbox"
    end
    
    -- Method 2: Reduce player's threat level
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            -- Make player less noticeable to AI
            humanoid.WalkSpeed = 0  -- Don't move while in safe zone
        end
    end
end

--====================================================
-- EMERGENCY PROTOCOLS
--====================================================
local function emergencyRestore()
    -- Restore everything to normal state
    
    -- Clean up decoy
    if states.DECOY then
        safeCall(function()
            states.DECOY:Destroy()
        end)
        states.DECOY = nil
    end
    
    -- Restore real character
    local character = LocalPlayer.Character
    if character then
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Restore original properties
            hrp.CanCollide = true
            hrp.Size = Vector3.new(2, 4, 1)
            hrp.Transparency = 0
            
            -- Remove forcefield if exists
            local ff = character:FindFirstChild("ForceField")
            if ff then
                ff:Destroy()
            end
        end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16  -- Restore normal speed
        end
    end
    
    -- Disconnect connections
    if states.CONNECTION then
        states.CONNECTION:Disconnect()
        states.CONNECTION = nil
    end
    
    states.ACTIVE = false
end

--====================================================
-- MAIN TOGGLE FUNCTION
--====================================================
local function toggleDecoySystem()
    local character = LocalPlayer.Character
    if not character then return end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not hrp or not humanoid then return end
    
    states.ACTIVE = not states.ACTIVE
    
    if states.ACTIVE then
        -- Store real HRP reference
        states.REAL_HRP = hrp
        
        -- Preserve original properties
        preserveOriginalProperties(character)
        
        -- Create decoy at current position
        states.DECOY = createMobDecoy(hrp.Position)
        
        -- Teleport real character to safe zone
        teleportToSafeZone(character)
        
        -- Set up mob redirection
        redirectMobAggro()
        
        -- Start movement handler
        states.CONNECTION = RunService.Heartbeat:Connect(function()
            safeCall(updateDecoyMovement)
        end)
        
        return true
    else
        -- Emergency restore to normal
        emergencyRestore()
        return false
    end
end

--====================================================
-- INPUT HANDLING
--====================================================
local lastToggleTime = 0
local TOGGLE_COOLDOWN = 0.5

local function handleToggleInput(input, gameProcessed)
    if gameProcessed then return end
    
    -- Toggle with F5 key (configurable)
    if input.KeyCode == Enum.KeyCode.F5 then
        local currentTime = tick()
        if currentTime - lastToggleTime >= TOGGLE_COOLDOWN then
            lastToggleTime = currentTime
            
            local success = safeCall(toggleDecoySystem)
            if success then
                print("Decoy system toggled:", states.ACTIVE and "ACTIVE" : "INACTIVE")
            end
        end
    end
    
    -- Emergency restore with F6
    if input.KeyCode == Enum.KeyCode.F6 then
        safeCall(emergencyRestore)
        print("Emergency restore executed")
    end
end

--====================================================
-- INITIALIZATION
--====================================================
local function initialize()
    if not validateEnvironment() then
        warn("Environment validation failed. Script may not work properly.")
        return
    end
    
    -- Wait for character
    if not LocalPlayer.Character then
        LocalPlayer.CharacterAdded:Wait()
    end
    
    -- Create UI
    local toggleBtn = createMinimalUI()
    
    -- Set up button click
    toggleBtn.MouseButton1Click:Connect(function()
        safeCall(toggleDecoySystem)
        toggleBtn.Text = states.ACTIVE and "SYSTEM\nACTIVE" or "SYSTEM\nOFF"
        toggleBtn.BackgroundColor3 = states.ACTIVE and Color3.fromRGB(0, 100, 0) 
                                         or Color3.fromRGB(30, 30, 30)
    end)
    
    -- Set up keyboard input
    UserInputService.InputBegan:Connect(handleToggleInput)
    
    -- Auto-cleanup on respawn
    LocalPlayer.CharacterAdded:Connect(function(character)
        task.wait(0.5)  -- Wait for character to fully load
        if states.ACTIVE then
            emergencyRestore()
            toggleBtn.Text = "SYSTEM\nOFF"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        end
    end)
    
    -- Cleanup on leave
    game:BindToClose(function()
        emergencyRestore()
    end)
    
    print("Decoy system initialized successfully")
    print("Controls: F5 = Toggle, F6 = Emergency Restore")
end

--====================================================
-- START SCRIPT
--====================================================
-- Delay initialization to avoid detection
task.wait(math.random(1, 3))
safeCall(initialize)
