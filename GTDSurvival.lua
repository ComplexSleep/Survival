--====================================================
-- SERVICES
--====================================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

--====================================================
-- GARDEN TD TUNING (SAFE VALUES)
--====================================================
local MAX_VERTICAL_OFFSET = 65        -- stay < 80 (safe)
local FOLLOW_DISTANCE = 26            -- mobs hug this well
local SMOOTHNESS = 0.35
local CLUSTER_COUNT = 3               -- aggro amplification
local CLUSTER_RADIUS = 4

--====================================================
-- STATE
--====================================================
local isActive = false
local decoyPart, bodyPos
local clusterParts = {}
local conn

--====================================================
-- UI SETUP (YOUR UI, UNCHANGED)
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

minBtn.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	openDot.Visible = true
end)

openDot.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
	openDot.Visible = false
end)

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

	-- Garden TD usually toggles a build UI
	for _, g in ipairs(gui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Name:lower():find("build") then
			return true
		end
	end
	return false
end

--====================================================
-- DECOY CREATION
--====================================================
local function createDecoy(hrp)
	decoyPart = Instance.new("Part")
	decoyPart.Name = "SoftDecoy"
	decoyPart.Size = Vector3.new(2, 2, 1)
	decoyPart.Transparency = 1
	decoyPart.CanCollide = false
	decoyPart.CFrame = hrp.CFrame
	decoyPart.Parent = Workspace

	bodyPos = Instance.new("BodyPosition")
	bodyPos.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyPos.P = 4000
	bodyPos.D = 600
	bodyPos.Position = decoyPart.Position
	bodyPos.Parent = decoyPart

	-- Aggro clustering
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

		-- Hide real body
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
			end
		end

		conn = RunService.Heartbeat:Connect(function()
			if not decoyPart or not bodyPos then return end

			-- Freeze player while building
			if isBuildMode() then
				hum:Move(Vector3.zero)
			end

			local moveDir = hum.MoveDirection
			local target = hrp.Position + moveDir * FOLLOW_DISTANCE

			-- Clamp vertical offset
			local yOffset = math.clamp(
				target.Y - hrp.Position.Y,
				-MAX_VERTICAL_OFFSET,
				MAX_VERTICAL_OFFSET
			)

			target = Vector3.new(target.X, hrp.Position.Y + yOffset, target.Z)
			target = groundSnap(target)

			bodyPos.Position = bodyPos.Position:Lerp(target, SMOOTHNESS)

			-- Lift real hitbox safely away
			hrp.CFrame = CFrame.new(
				bodyPos.Position + Vector3.new(0, MAX_VERTICAL_OFFSET, 0)
			)

			Camera.CameraSubject = hum
		end)

		toggleBtn.Text = "PILOT ACTIVE"
		toggleBtn.BackgroundColo
