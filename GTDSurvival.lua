-- 1. INITIALIZATION
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- SETTINGS
local isActive = false
local DESYNC_HEIGHT = 150 
local OFFSET_DISTANCE = 35 
local ORBIT_RADIUS = 20    
local ORBIT_SPEED = 14     
local decoy = nil

-- 2. UI SETUP
local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
screenGui.Name = "ShadowLinkUI_Optimized"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 220, 0, 80)
mainFrame.Position = UDim2.new(0.5, -110, 0.05, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
Instance.new("UICorner", mainFrame)

local toggleBtn = Instance.new("TextButton", mainFrame)
toggleBtn.Size = UDim2.new(1, -20, 0, 40)
toggleBtn.Position = UDim2.new(0, 10, 0, 30)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
toggleBtn.Text = "START PILOT"
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", toggleBtn)

local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.new(0, 25, 0, 25)
minBtn.Position = UDim2.new(1, -30, 0, 5)
minBtn.BackgroundTransparency = 1
minBtn.Text = "-"
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.TextSize = 25

local openDot = Instance.new("TextButton", screenGui)
openDot.Size = UDim2.new(0, 15, 0, 15)
openDot.Position = UDim2.new(0, 15, 1, -30)
openDot.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
openDot.Text = ""
openDot.Visible = false
openDot.ZIndex = 10
Instance.new("UICorner", openDot)

-- UI TOGGLES
minBtn.MouseButton1Click:Connect(function() mainFrame.Visible = false; openDot.Visible = true end)
openDot.MouseButton1Click:Connect(function() mainFrame.Visible = true; openDot.Visible = false end)

-- 3. THE LOGIC
local function toggleQuantum()
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChild("Humanoid")
	
	if not hrp or not hum then return end
	isActive = not isActive
	
	if isActive then
		char.Archivable = true
		decoy = char:Clone()
		decoy.Parent = workspace
		
		-- Setup Decoy
		for _, part in pairs(decoy:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0.3
				part.CanCollide = false
			end
		end
		
		-- Setup Real Body
		for _, part in pairs(char:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 1
				part.CanCollide = false
			end
		end
		
		-- Voids-Proofing: Force gravity to zero for the HRP
		local bv = Instance.new("BodyVelocity")
		bv.Name = "QuantumFloat"
		bv.Velocity = Vector3.new(0, 0, 0)
		bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bv.Parent = hrp

		_G.QuantumLoop = RunService.Heartbeat:Connect(function()
			if not hrp or not decoy or not decoy.PrimaryPart then return end
			
			local t = tick() * ORBIT_SPEED
			local x = math.cos(t) * ORBIT_RADIUS
			local z = math.sin(t) * ORBIT_RADIUS
			
			local relativeOffset = Vector3.new(x, DESYNC_HEIGHT, z - OFFSET_DISTANCE)
			local targetPos = decoy.PrimaryPart.CFrame:PointToWorldSpace(relativeOffset)
			
			-- Use CFrame to prevent falling
			hrp.CFrame = CFrame.new(targetPos) 
			
			-- Movement
			local moveDir = hum.MoveDirection
			if moveDir.Magnitude > 0 then
				decoy:TranslateBy(moveDir * (hum.WalkSpeed / 60))
				decoy.PrimaryPart.CFrame = CFrame.lookAt(decoy.PrimaryPart.Position, decoy.PrimaryPart.Position + moveDir)
			end
			
			Camera.CameraSubject = decoy:FindFirstChild("Humanoid")
		end)
		
		toggleBtn.Text = "PILOT ACTIVE"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
	else
		if _G.QuantumLoop then _G.QuantumLoop:Disconnect(); _G.QuantumLoop = nil end
		if hrp:FindFirstChild("QuantumFloat") then hrp.QuantumFloat:Destroy() end
		
		if decoy then
			char:MoveTo(decoy.PrimaryPart.Position)
			decoy:Destroy()
			decoy = nil
		end
		
		hrp.Velocity = Vector3.new(0,0,0)
		for _, part in pairs(char:GetChildren()) do
			if part:IsA("BasePart") then part.Transparency = 0 part.CanCollide = true end
		end
		
		Camera.CameraSubject = hum
		toggleBtn.Text = "START PILOT"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
	end
end

toggleBtn.MouseButton1Click:Connect(toggleQuantum)
