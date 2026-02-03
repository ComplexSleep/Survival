--====================================================
-- SERVICES
--====================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local function clamp(v, min, max)
	if v < min then return min end
	if v > max then return max end
	return v
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--====================================================
-- GARDEN TD TUNING (SAFE VALUES)
--====================================================
local MAX_VERTICAL_OFFSET = 65
local FOLLOW_DISTANCE = 26
local SMOOTHNESS = 0.35
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
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShadowLinkUI_Optimized"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 999
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

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

--====================================================
-- UTILITIES
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
-- DECOY LOGIC
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
	bodyPos.MaxForce = Vector3.new(5e4, 5e4, 5e4)
	bodyPos.P = 3500
	bodyPos.D = 500
	bodyPos.Position = decoyPart.Position
	bodyPos.Parent = decoyPart

	clusterParts = {}
	for i = 1, CLUSTER_COUNT do
		local p = Instance.new("Part")
		p.Size = Vector3.new(2,2,2)
		p.Transparency = 1
		p.CanCollide = false
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
-- TOGGLE LOGIC
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

		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") and d ~= hrp then
				d.Transparency = 1
				d.CanCollide = false
			end
		end

		conn = RunService.Heartbeat:Connect(function()
			if not decoyPart or not bodyPos then return end

			if isBuildMode() then
				hum:Move(Vector3.zero, false)
			end

			local target = hrp.Position + hum.MoveDirection * FOLLOW_DISTANCE
			local yOffset = clamp(
				target.Y - hrp.Position.Y,
				-MAX_VERTICAL_OFFSET,
				MAX_VERTICAL_OFFSET
			)

			target = Vector3.new(target.X, hrp.Position.Y + yOffset, target.Z)
			target = groundSnap(target)

			bodyPos.Position = bodyPos.Position:Lerp(target, SMOOTHNESS)

			for i, p in ipairs(clusterParts) do
				p.CFrame = decoyPart.CFrame * CFrame.new(
					math.sin(i * 2) * CLUSTER_RADIUS,
					0,
					math.cos(i * 2) * CLUSTER_RADIUS
				)
			end

			hrp.CFrame = CFrame.new(
				bodyPos.Position + Vector3.new(0, MAX_VERTICAL_OFFSET, 0)
			)

			Camera.CameraSubject = hum
		end)

		toggleBtn.Text = "PILOT ACTIVE"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 50)

	else
		destroyDecoy()

		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 0
				d.CanCollide = true
			end
		end

		Camera.CameraSubject = hum
		toggleBtn.Text = "START PILOT"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
	end
end

toggleBtn.MouseButton1Click:Connect(togglePilot)

--====================================================
-- RESPAWN SAFETY
--====================================================
LocalPlayer.CharacterAdded:Connect(function()
	isActive = false
	destroyDecoy()
	Camera.CameraSubject = LocalPlayer.Character:WaitForChild("Humanoid")
end)
