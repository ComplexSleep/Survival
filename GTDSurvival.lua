--====================================================
-- LOAD SAFETY
--====================================================
if not game:IsLoaded() then game.Loaded:Wait() end

--====================================================
-- SERVICES
--====================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--====================================================
-- UTIL
--====================================================
local function clamp(v, min, max)
	if v < min then return min end
	if v > max then return max end
	return v
end

--====================================================
-- GARDEN TD SAFE TUNING
--====================================================
local FOLLOW_DISTANCE = 26
local SMOOTHNESS = 0.35
local MAX_VERTICAL_OFFSET = 65
local CLUSTER_COUNT = 3
local CLUSTER_RADIUS = 4

--====================================================
-- STATE
--====================================================
local isActive = false
local decoyPart, bodyPos
local clusterParts = {}
local conn

--====================================================
-- UI SETUP
--====================================================
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
toggleBtn.TextColor3 = Color3.new(1,1,1)
toggleBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", toggleBtn)

local minBtn = Instance.new("TextButton", mainFrame)
minBtn.Size = UDim2.new(0, 25, 0, 25)
minBtn.Position = UDim2.new(1, -30, 0, 5)
minBtn.BackgroundTransparency = 1
minBtn.Text = "-"
minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.TextSize = 25

local openDot = Instance.new("TextButton", screenGui)
openDot.Size = UDim2.new(0, 15, 0, 15)
openDot.Position = UDim2.new(0, 15, 1, -30)
openDot.BackgroundColor3 = Color3.fromRGB(0,255,150)
openDot.Text = ""
openDot.Visible = false
openDot.ZIndex = 10
Instance.new("UICorner", openDot)

minBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	openDot.Visible = true
end)

openDot.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
	openDot.Visible = false
end)

--====================================================
-- GROUND SNAP
--====================================================
local function groundSnap(pos)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {LocalPlayer.Character}
	params.FilterType = Enum.RaycastFilterType.Blacklist

	local result = Workspace:Raycast(
		pos + Vector3.new(0, 50, 0),
		Vector3.new(0, -200, 0),
		params
	)

	if result then
		return Vector3.new(pos.X, result.Position.Y + 2.5, pos.Z)
	end
	return pos
end

--====================================================
-- BUILD MODE DETECTION
--====================================================
local function isBuildMode()
	local gui = LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then return false end

	for _, g in ipairs(gui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Name:lower():find("build") then
			return true
		end
	end
	return false
end

--====================================================
-- DECOY
--====================================================
local function createDecoy(hrp)
	decoyPart = Instance.new("Part")
	decoyPart.Name = "SoftDecoy"
	decoyPart.Size = Vector3.new(2,2,1)
	decoyPart.Transparency = 1
	decoyPart.CanCollide = false
	decoyPart.CFrame = hrp.CFrame
	decoyPart.Parent = Workspace

	bodyPos = Instance.new("BodyPosition")
	bodyPos.MaxForce = Vector3.new(1e5,1e5,1e5)
	bodyPos.P = 4000
	bodyPos.D = 600
	bodyPos.Position = decoyPart.Position
	bodyPos.Parent = decoyPart

	for i = 1, CLUSTER_COUNT do
		local p = Instance.new("Part")
		p.Size = Vector3.new(2,2,2)
		p.Transparency = 1
		p.CanCollide = false
		p.CFrame = decoyPart.CFrame * CFrame.new(
			math.random(-CLUSTER_RADIUS, CLUSTER_RADIUS),
			0,
			math.random(-CLUSTER_RADIUS, CLUSTER_RADIUS)
		)
		p.Parent = decoyPart
		table.insert(clusterParts, p)
	end
end

local function destroyDecoy()
	if conn then conn:Disconnect() conn = nil end
	if decoyPart then decoyPart:Destroy() end
	decoyPart, bodyPos = nil, nil
	clusterParts = {}
end

--====================================================
-- EMERGENCY UNSTUCK (HOTKEY: H)
--====================================================
local function emergencyUnstuck()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local safePos = groundSnap(hrp.Position)

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(safePos)

	if decoyPart and bodyPos then
		bodyPos.Position = safePos
	end
end

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.H then
		emergencyUnstuck()
	end
end)

--====================================================
-- TOGGLE PILOT
--====================================================
local function togglePilot()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChild("Humanoid")
	if not hrp or not hum then return end

	isActive = not isActive

	if isActive then
		createDecoy(hrp)

		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 1
				p.CanCollide = false
			end
		end

		conn = RunService.Heartbeat:Connect(function()
			if not decoyPart or not bodyPos then return end

			-- cancel physics
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero

			if isBuildMode() then
				hum:Move(Vector3.zero, false)
			end

			local moveDir = hum.MoveDirection
			local target = hrp.Position + moveDir * FOLLOW_DISTANCE
			target = groundSnap(target)

			bodyPos.Position = bodyPos.Position:Lerp(target, SMOOTHNESS)

			-- keep real player grounded
			local grounded = groundSnap(hrp.Position)
			hrp.CFrame = CFrame.new(grounded, grounded + hrp.CFrame.LookVector)

			Camera.CameraSubject = hum
		end)

		toggleBtn.Text = "PILOT ACTIVE"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(0,200,50)
	else
		destroyDecoy()

		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 0
				p.CanCollide = true
			end
		end

		Camera.CameraSubject = hum
		toggleBtn.Text = "START PILOT"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(20,60,20)
	end
end

toggleBtn.MouseButton1Click:Connect(togglePilot)

--====================================================
-- RESPAWN SAFETY
--====================================================
LocalPlayer.CharacterAdded:Connect(function(char)
	isActive = false
	destroyDecoy()
	Camera.CameraSubject = char:WaitForChild("Humanoid")
end)
