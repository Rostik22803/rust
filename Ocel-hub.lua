-- language: Luau, file: esp_aimbot.lua, runtime: Roblox Luau (Mobile & PC Executors), target: Place 107103871057311
-- Ocel-hub: Monochrome Black & White UI, Mobile-first Touch Controls, 3D-projected Boxes,
-- 2-pass R15/R6 Skeletons, Names/Distance/Weapon/HP, Bots & Sleepers, Ballistic Aimbot.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local IsMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

if getgenv and getgenv()._OcelHubUnload then
    pcall(getgenv()._OcelHubUnload)
elseif getgenv and getgenv()._VantaESPUnload then
    pcall(getgenv()._VantaESPUnload)
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
local Config = {
    ESP = {
        Enabled = true,
        TeamCheck = false,          -- true = hide teammates
        ShowTeammates = true,
        ShowBots = true,            -- workspace.Scientists
        ShowSleepers = true,        -- workspace.Sleepers
        MaxDistance = 1200,         -- studs (~336m)
        Box = true,
        BoxStyle = "Corners",       -- "Corners" | "Full"
        BoxFill = true,
        BoxFillAlpha = 0.10,
        Skeleton = true,
        SkeletonThickness = 1.5,
        SkeletonMinHeight = 34,     -- hide skeleton when box height < 34px so distant targets stay clean
        HeadDot = false,
        Name = true,
        Distance = true,
        Weapon = true,
        HealthBar = true,
        HealthText = true,
        IgnoreDowned = false,
        Colors = {
            Enemy = Color3.fromRGB(255, 72, 72),
            EnemyVisible = Color3.fromRGB(255, 200, 70),
            Teammate = Color3.fromRGB(90, 215, 130),
            Downed = Color3.fromRGB(190, 125, 255),
            Bot = Color3.fromRGB(80, 190, 255),
            BotVisible = Color3.fromRGB(150, 235, 255),
            Sleeper = Color3.fromRGB(170, 178, 195),
            Skeleton = Color3.fromRGB(245, 245, 245),
            SkeletonDowned = Color3.fromRGB(190, 125, 255),
            SkeletonBot = Color3.fromRGB(185, 235, 255),
            SkeletonSleeper = Color3.fromRGB(185, 195, 210),
            Text = Color3.fromRGB(245, 245, 245),
            Outline = Color3.fromRGB(10, 10, 10),
        },
    },
    Aimbot = {
        Enabled = true,
        SilentAim = true,           -- redirects shots inside FOV without snapping camera
        SilentHitChance = 100,      -- % of shots redirected
        SilentSnapline = true,      -- draws subtle line to locked silent target
        TriggerMode = IsMobile and "Button" or "ADS", -- "Button" | "ADS" | "Always"
        ButtonMode = "Hold",        -- "Hold" | "Toggle" (for floating AIM button)
        FOV = 135,                  -- pixels radius
        ShowFOV = true,
        FOVColor = Color3.fromRGB(255, 255, 255),
        Smoothness = 4.5,           -- 1 = instant snap, 4-8 = smooth legit
        MaxDegPerSec = 580,         -- angular speed cap (AimWatchLook safe)
        TargetPart = "Head",        -- "Head" | "UpperTorso" | "Closest" | "LowerTorso"
        TargetPlayers = true,
        TargetBots = true,
        TargetSleepers = false,
        TeamCheck = true,
        VisibilityCheck = true,
        IgnoreDowned = true,
        StickyTarget = true,
        Prediction = true,
        GravityComp = true,
        FallbackBulletSpeed = 1000,
        FallbackGravity = 60,
        MaxDistance = 1000,
    },
    UI = {
        Open = not IsMobile,        -- on mobile start collapsed to clean OCEL pill
        ToggleKey = Enum.KeyCode.Insert,
        AltToggleKey = Enum.KeyCode.RightShift,
    },
}

local METRES_PER_STUD = 0.28

-- ============================================================================
-- RIG DEFINITIONS (R15 + R6)
-- ============================================================================
local R15_BONES = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local R6_BONES = {
    { "Head", "Torso" },
    { "Torso", "Left Arm" },
    { "Torso", "Right Arm" },
    { "Torso", "Left Leg" },
    { "Torso", "Right Leg" },
}

-- Simplified 7-bone LOD skeleton for distant models (prevents 14-bone overlap into a blob)
local R15_LOD_BONES = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftHand" },
    { "UpperTorso", "RightHand" },
    { "LowerTorso", "LeftFoot" },
    { "LowerTorso", "RightFoot" },
}

local AMMO_SPEED_MULT = {
    ExplosiveRifleAmmo = 0.8,
    IncendiaryRifleAmmo = 0.8,
    HVRifleAmmo = 1.2,
    HVPistolAmmo = 1.33,
    IncendiaryPistolAmmo = 0.75,
    Shell = 0.44,
    IncendiaryShell = 0.44,
    HVArrow = 1.6,
    BoneArrow = 0.9,
}

local BBOX_PARTS = {
    "Head", "UpperTorso", "LowerTorso", "Torso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

local CORNER_SIGNS = {
    Vector3.new(-1, -1, -1), Vector3.new( 1, -1, -1),
    Vector3.new(-1,  1, -1), Vector3.new( 1,  1, -1),
    Vector3.new(-1, -1,  1), Vector3.new( 1, -1,  1),
    Vector3.new(-1,  1,  1), Vector3.new( 1,  1,  1),
}

-- ============================================================================
-- STATE & GAME HELPERS
-- ============================================================================
local Connections = {}
local ESPPool = {}          -- [Player] -> ESP
local EntityPool = {}       -- [Model] -> { entry = ESP, kind = "Bot"|"Sleeper" }
local TeammateIds = {}      -- [UserId] = true
local VelocityCache = {}    -- [Model] -> { pos = Vector3, t = number, vel = Vector3 }
local LockedTarget = nil
local AimButtonHeld = false
local AimButtonToggled = false
local AimHasLock = false

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

local function AddConn(conn)
    table.insert(Connections, conn)
    return conn
end

local function IsPointerDownInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function IsPointerMoveInput(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function RefreshTeammates()
    table.clear(TeammateIds)
    local raw = LocalPlayer:GetAttribute("TeamMates")
    if type(raw) == "string" and raw ~= "" then
        for idStr in string.gmatch(raw, "%d+") do
            local uid = tonumber(idStr)
            if uid then
                TeammateIds[uid] = true
            end
        end
    end
end

local function IsTeammateUserId(uid)
    if type(uid) ~= "number" then return false end
    if uid == LocalPlayer.UserId or TeammateIds[uid] then return true end
    local myTid = LocalPlayer:GetAttribute("TeamId")
    if myTid ~= nil then
        for _, p in ipairs(Players:GetPlayers()) do
            if p.UserId == uid and p:GetAttribute("TeamId") == myTid then
                return true
            end
        end
    end
    return false
end

local function IsTeammate(player)
    if player == LocalPlayer then return true end
    if TeammateIds[player.UserId] then return true end
    local myTid = LocalPlayer:GetAttribute("TeamId")
    local theirTid = player:GetAttribute("TeamId")
    if myTid ~= nil and theirTid ~= nil and myTid == theirTid then return true end
    if LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then return true end
    return false
end

local function IsDowned(character)
    return character:GetAttribute("Downed") == true
end

local function GetModelHealth(model, allowNoHumanoid)
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum.Health, math.max(1, hum.MaxHealth), true
    end
    local attrHp = model:GetAttribute("Health")
    if type(attrHp) == "number" then
        local attrMax = model:GetAttribute("MaxHealth")
        local maxHp = (type(attrMax) == "number" and attrMax > 0) and attrMax or 100
        return attrHp, maxHp, true
    end
    if allowNoHumanoid then
        return 100, 100, false
    end
    return 0, 100, false
end

local function GetEquippedWeaponName(character)
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA("Tool") then
            return child.Name
        end
    end
    return nil
end

local function GetWeaponBallistics()
    local char = LocalPlayer.Character
    if not char then
        return Config.Aimbot.FallbackBulletSpeed, Config.Aimbot.FallbackGravity
    end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then
        return Config.Aimbot.FallbackBulletSpeed, Config.Aimbot.FallbackGravity
    end
    local speed = tool:GetAttribute("BulletSpeed") or Config.Aimbot.FallbackBulletSpeed
    local gravity = tool:GetAttribute("BulletGravity") or Config.Aimbot.FallbackGravity
    local speedMult = 1
    local muzzle = tool:FindFirstChild("Muzzle", true)
    if muzzle then
        local mSpeed = muzzle:GetAttribute("Speed")
        if type(mSpeed) == "number" then
            speedMult = speedMult * mSpeed
        end
    end
    local ammoType = tool:GetAttribute("LoadedType") or tool:GetAttribute("BaseAmmo")
    if type(ammoType) == "string" and AMMO_SPEED_MULT[ammoType] then
        speedMult = speedMult * AMMO_SPEED_MULT[ammoType]
    end
    return math.max(100, speed * speedMult), math.max(0, gravity)
end

local function GetSmoothedVelocity(char, part)
    local root = char:FindFirstChild("HumanoidRootPart") or part
    local pos = root.Position
    local now = os.clock()
    local rec = VelocityCache[char]
    if not rec then
        local initVel = root.AssemblyLinearVelocity
        if initVel.Magnitude > 50 then initVel = Vector3.zero end
        VelocityCache[char] = { pos = pos, t = now, vel = initVel }
        return initVel
    end

    local dt = now - rec.t
    if dt >= 0.015 then
        local instVel = (pos - rec.pos) / math.max(dt, 0.016)
        -- Reject teleport / streaming spikes
        if instVel.Magnitude > 65 then
            instVel = rec.vel
        else
            -- Dampen vertical network/slope jitter
            instVel = Vector3.new(instVel.X, instVel.Y * 0.45, instVel.Z)
        end
        local alpha = math.clamp(dt * 12, 0.15, 0.65)
        rec.vel = rec.vel:Lerp(instVel, alpha)
        rec.pos = pos
        rec.t = now
    end

    if rec.vel.Magnitude < 1.2 then
        return Vector3.zero
    end
    return rec.vel
end

local function IsPartVisible(targetPart, targetCharacter)
    if not Camera then return false end
    local origin = Camera.CFrame.Position
    local dir = targetPart.Position - origin
    if dir.Magnitude < 0.5 then return true end

    local ignore = { Camera }
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    local dropped = Workspace:FindFirstChild("DroppedItems")
    if dropped then table.insert(ignore, dropped) end
    local arrows = Workspace:FindFirstChild("StuckArrows")
    if arrows then table.insert(ignore, arrows) end
    local tracers = Workspace:FindFirstChild("FirearmsTracers")
    if tracers then table.insert(ignore, tracers) end
    RayParams.FilterDescendantsInstances = ignore

    for _ = 1, 6 do
        local result = Workspace:Raycast(origin, dir, RayParams)
        if not result then
            return true
        end
        local hit = result.Instance
        if hit:IsDescendantOf(targetCharacter) then
            return true
        end
        if not hit.CanQuery or (not hit.CanCollide and hit.Transparency >= 0.45) then
            table.insert(ignore, hit)
            RayParams.FilterDescendantsInstances = ignore
        else
            return false
        end
    end
    return false
end

local function ProjectPoint(worldPos)
    local vec, onScreen = Camera:WorldToViewportPoint(worldPos)
    return Vector2.new(vec.X, vec.Y), vec.Z, onScreen
end

local function ComputeScreenBox(character)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyInFront = false

    for _, partName in ipairs(BBOX_PARTS) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            local cf = part.CFrame
            local half = part.Size * 0.5
            for i = 1, 8 do
                local s = CORNER_SIGNS[i]
                local worldCorner = cf:PointToWorldSpace(Vector3.new(half.X * s.X, half.Y * s.Y, half.Z * s.Z))
                local sp, z = ProjectPoint(worldCorner)
                if z > 0.1 then
                    anyInFront = true
                    if sp.X < minX then minX = sp.X end
                    if sp.Y < minY then minY = sp.Y end
                    if sp.X > maxX then maxX = sp.X end
                    if sp.Y > maxY then maxY = sp.Y end
                end
            end
        end
    end

    if not anyInFront or minX == math.huge then return nil end

    local vp = Camera.ViewportSize
    if maxX < -200 or minX > vp.X + 200 or maxY < -200 or minY > vp.Y + 200 then
        return nil
    end

    return minX, minY, math.max(8, maxX - minX), math.max(12, maxY - minY)
end

local function HealthColor(ratio)
    ratio = math.clamp(ratio, 0, 1)
    if ratio > 0.5 then
        local t = (ratio - 0.5) * 2
        return Color3.fromRGB(math.floor(255 * (1 - t) + 70 * t), 235, 65)
    else
        local t = ratio * 2
        return Color3.fromRGB(245, math.floor(55 + 180 * t), 55)
    end
end

-- ============================================================================
-- DRAWING POOL (ESP)
-- ============================================================================
local function NewDraw(kind, props)
    local obj = Drawing.new(kind)
    for k, v in pairs(props) do
        obj[k] = v
    end
    return obj
end

local function CreateESPEntry()
    local entry = {
        BoxFill = NewDraw("Square", { Visible = false, Filled = true, Thickness = 0, Transparency = 0.10 }),
        BoxOutline = NewDraw("Square", { Visible = false, Filled = false, Thickness = 3, Color = Config.ESP.Colors.Outline }),
        Box = NewDraw("Square", { Visible = false, Filled = false, Thickness = 1 }),
        CornersOutline = {},
        Corners = {},
        SkeletonOutline = {},
        Skeleton = {},
        HeadDotOutline = NewDraw("Circle", { Visible = false, Filled = false, Thickness = 2.5, NumSides = 20, Color = Config.ESP.Colors.Outline }),
        HeadDot = NewDraw("Circle", { Visible = false, Filled = false, Thickness = 1.2, NumSides = 20 }),
        HPBack = NewDraw("Square", { Visible = false, Filled = true, Thickness = 0, Color = Config.ESP.Colors.Outline }),
        HPFill = NewDraw("Square", { Visible = false, Filled = true, Thickness = 0 }),
        HPText = NewDraw("Text", { Visible = false, Size = 12, Center = false, Outline = true, Font = 2, Color = Config.ESP.Colors.Text }),
        NameText = NewDraw("Text", { Visible = false, Size = 13, Center = true, Outline = true, Font = 2, Color = Config.ESP.Colors.Text }),
        SubText = NewDraw("Text", { Visible = false, Size = 12, Center = true, Outline = true, Font = 2, Color = Color3.fromRGB(210, 210, 210) }),
    }

    for i = 1, 8 do
        entry.CornersOutline[i] = NewDraw("Line", { Visible = false, Thickness = 3, Color = Config.ESP.Colors.Outline })
        entry.Corners[i] = NewDraw("Line", { Visible = false, Thickness = 1.3 })
    end

    for i = 1, #R15_BONES do
        entry.SkeletonOutline[i] = NewDraw("Line", { Visible = false, Thickness = 3.2, Color = Config.ESP.Colors.Outline })
        entry.Skeleton[i] = NewDraw("Line", { Visible = false, Thickness = 1.5 })
    end

    return entry
end

local function HideESPEntry(entry)
    entry.BoxFill.Visible = false
    entry.BoxOutline.Visible = false
    entry.Box.Visible = false
    entry.HeadDotOutline.Visible = false
    entry.HeadDot.Visible = false
    entry.HPBack.Visible = false
    entry.HPFill.Visible = false
    entry.HPText.Visible = false
    entry.NameText.Visible = false
    entry.SubText.Visible = false
    for i = 1, 8 do
        entry.CornersOutline[i].Visible = false
        entry.Corners[i].Visible = false
    end
    for i = 1, #entry.Skeleton do
        entry.SkeletonOutline[i].Visible = false
        entry.Skeleton[i].Visible = false
    end
end

local function DestroyESPEntry(entry)
    pcall(function()
        entry.BoxFill:Remove()
        entry.BoxOutline:Remove()
        entry.Box:Remove()
        entry.HeadDotOutline:Remove()
        entry.HeadDot:Remove()
        entry.HPBack:Remove()
        entry.HPFill:Remove()
        entry.HPText:Remove()
        entry.NameText:Remove()
        entry.SubText:Remove()
        for i = 1, 8 do
            entry.CornersOutline[i]:Remove()
            entry.Corners[i]:Remove()
        end
        for i = 1, #entry.Skeleton do
            entry.SkeletonOutline[i]:Remove()
            entry.Skeleton[i]:Remove()
        end
    end)
end

local function DrawCorners(entry, x, y, w, h, color)
    local cw = math.max(4, math.min(w * 0.28, 18))
    local ch = math.max(4, math.min(h * 0.28, 18))
    local segs = {
        { Vector2.new(x, y), Vector2.new(x + cw, y) },
        { Vector2.new(x, y), Vector2.new(x, y + ch) },
        { Vector2.new(x + w, y), Vector2.new(x + w - cw, y) },
        { Vector2.new(x + w, y), Vector2.new(x + w, y + ch) },
        { Vector2.new(x, y + h), Vector2.new(x + cw, y + h) },
        { Vector2.new(x, y + h), Vector2.new(x, y + h - ch) },
        { Vector2.new(x + w, y + h), Vector2.new(x + w - cw, y + h) },
        { Vector2.new(x + w, y + h), Vector2.new(x + w, y + h - ch) },
    }
    for i = 1, 8 do
        local a, b = segs[i][1], segs[i][2]
        local ol = entry.CornersOutline[i]
        ol.From = a
        ol.To = b
        ol.Visible = true
        local ln = entry.Corners[i]
        ln.From = a
        ln.To = b
        ln.Color = color
        ln.Visible = true
    end
end

local function RenderModelESP(entry, char, opts)
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
    if not hrp then
        HideESPEntry(entry)
        return
    end

    local distStuds = (hrp.Position - Camera.CFrame.Position).Magnitude
    if distStuds > Config.ESP.MaxDistance then
        HideESPEntry(entry)
        return
    end

    local x, y, w, h = ComputeScreenBox(char)
    if not x then
        HideESPEntry(entry)
        return
    end

    local head = char:FindFirstChild("Head")
    local mainColor = opts.mainColor
    local skelColor = opts.skelColor

    if Config.ESP.Box and Config.ESP.BoxFill then
        entry.BoxFill.Position = Vector2.new(x, y)
        entry.BoxFill.Size = Vector2.new(w, h)
        entry.BoxFill.Color = mainColor
        entry.BoxFill.Transparency = Config.ESP.BoxFillAlpha
        entry.BoxFill.Visible = true
    else
        entry.BoxFill.Visible = false
    end

    if Config.ESP.Box then
        if Config.ESP.BoxStyle == "Full" then
            for i = 1, 8 do
                entry.CornersOutline[i].Visible = false
                entry.Corners[i].Visible = false
            end
            entry.BoxOutline.Position = Vector2.new(x, y)
            entry.BoxOutline.Size = Vector2.new(w, h)
            entry.BoxOutline.Visible = true

            entry.Box.Position = Vector2.new(x, y)
            entry.Box.Size = Vector2.new(w, h)
            entry.Box.Color = mainColor
            entry.Box.Visible = true
        else
            entry.BoxOutline.Visible = false
            entry.Box.Visible = false
            DrawCorners(entry, x, y, w, h, mainColor)
        end
    else
        entry.BoxOutline.Visible = false
        entry.Box.Visible = false
        for i = 1, 8 do
            entry.CornersOutline[i].Visible = false
            entry.Corners[i].Visible = false
        end
    end

    if Config.ESP.Skeleton and h >= Config.ESP.SkeletonMinHeight then
        local ut = char:FindFirstChild("UpperTorso")
        local lt = char:FindFirstChild("LowerTorso")
        local thick = math.max(1.0, Config.ESP.SkeletonThickness * math.clamp(h / 75, 0.7, 1))
        local useOutline = (h >= 54)
        local outlineThick = thick + 1.6
        local segs = {}

        if ut and lt and ut:IsA("BasePart") and lt:IsA("BasePart") then
            local utCF, utSz = ut.CFrame, ut.Size
            local ltCF, ltSz = lt.CFrame, lt.Size
            local neck = utCF:PointToWorldSpace(Vector3.new(0, utSz.Y * 0.45, 0))
            local pelvis = ltCF:PointToWorldSpace(Vector3.new(0, -ltSz.Y * 0.25, 0))
            local lShoulder = utCF:PointToWorldSpace(Vector3.new(-utSz.X * 0.48, utSz.Y * 0.34, 0))
            local rShoulder = utCF:PointToWorldSpace(Vector3.new( utSz.X * 0.48, utSz.Y * 0.34, 0))
            local lHip = ltCF:PointToWorldSpace(Vector3.new(-ltSz.X * 0.34, -ltSz.Y * 0.28, 0))
            local rHip = ltCF:PointToWorldSpace(Vector3.new( ltSz.X * 0.34, -ltSz.Y * 0.28, 0))

            local function pPos(name)
                local p = char:FindFirstChild(name)
                return (p and p:IsA("BasePart")) and p.Position or nil
            end

            local headPos = pPos("Head")
            local lElbow = pPos("LeftLowerArm") or pPos("LeftUpperArm")
            local lHand = pPos("LeftHand") or lElbow
            local rElbow = pPos("RightLowerArm") or pPos("RightUpperArm")
            local rHand = pPos("RightHand") or rElbow
            local lKnee = pPos("LeftLowerLeg") or pPos("LeftUpperLeg")
            local lFoot = pPos("LeftFoot") or lKnee
            local rKnee = pPos("RightLowerLeg") or pPos("RightUpperLeg")
            local rFoot = pPos("RightFoot") or rKnee

            if headPos then table.insert(segs, { headPos, neck }) end
            table.insert(segs, { neck, pelvis })
            table.insert(segs, { neck, lShoulder })
            table.insert(segs, { neck, rShoulder })
            if lElbow then table.insert(segs, { lShoulder, lElbow }) end
            if lElbow and lHand and lHand ~= lElbow then table.insert(segs, { lElbow, lHand }) end
            if rElbow then table.insert(segs, { rShoulder, rElbow }) end
            if rElbow and rHand and rHand ~= rElbow then table.insert(segs, { rElbow, rHand }) end
            table.insert(segs, { pelvis, lHip })
            table.insert(segs, { pelvis, rHip })
            if lKnee then table.insert(segs, { lHip, lKnee }) end
            if lKnee and lFoot and lFoot ~= lKnee then table.insert(segs, { lKnee, lFoot }) end
            if rKnee then table.insert(segs, { rHip, rKnee }) end
            if rKnee and rFoot and rFoot ~= rKnee then table.insert(segs, { rKnee, rFoot }) end
        else
            for _, pair in ipairs(R6_BONES) do
                local pA = char:FindFirstChild(pair[1])
                local pB = char:FindFirstChild(pair[2])
                if pA and pB and pA:IsA("BasePart") and pB:IsA("BasePart") then
                    table.insert(segs, { pA.Position, pB.Position })
                end
            end
        end

        for i = 1, #entry.Skeleton do
            local seg = segs[i]
            if seg then
                local posA, zA = ProjectPoint(seg[1])
                local posB, zB = ProjectPoint(seg[2])
                if zA > 0.2 and zB > 0.2 then
                    if useOutline then
                        local ol = entry.SkeletonOutline[i]
                        ol.From = posA
                        ol.To = posB
                        ol.Thickness = outlineThick
                        ol.Visible = true
                    else
                        entry.SkeletonOutline[i].Visible = false
                    end
                    local ln = entry.Skeleton[i]
                    ln.From = posA
                    ln.To = posB
                    ln.Color = skelColor
                    ln.Thickness = thick
                    ln.Visible = true
                else
                    entry.SkeletonOutline[i].Visible = false
                    entry.Skeleton[i].Visible = false
                end
            else
                entry.SkeletonOutline[i].Visible = false
                entry.Skeleton[i].Visible = false
            end
        end
    else
        for i = 1, #entry.Skeleton do
            entry.SkeletonOutline[i].Visible = false
            entry.Skeleton[i].Visible = false
        end
    end

    if Config.ESP.HeadDot and head and head:IsA("BasePart") then
        local hp, hz = ProjectPoint(head.Position)
        if hz > 0.2 then
            local radius = math.clamp((head.Size.Y * 0.5 / hz) * Camera.ViewportSize.Y * 0.65, 2.5, 24)
            entry.HeadDotOutline.Position = hp
            entry.HeadDotOutline.Radius = radius
            entry.HeadDotOutline.Visible = true

            entry.HeadDot.Position = hp
            entry.HeadDot.Radius = radius
            entry.HeadDot.Color = mainColor
            entry.HeadDot.Visible = true
        else
            entry.HeadDotOutline.Visible = false
            entry.HeadDot.Visible = false
        end
    else
        entry.HeadDotOutline.Visible = false
        entry.HeadDot.Visible = false
    end

    if Config.ESP.HealthBar and opts.hasHealth then
        local maxHp = math.max(1, opts.maxHp)
        local hp = math.clamp(opts.hp, 0, maxHp)
        local hpRatio = hp / maxHp
        local barW = 3
        local barX = x - 6
        local fillH = math.max(1, h * hpRatio)
        local fillY = y + (h - fillH)

        entry.HPBack.Position = Vector2.new(barX - 1, y - 1)
        entry.HPBack.Size = Vector2.new(barW + 2, h + 2)
        entry.HPBack.Visible = true

        entry.HPFill.Position = Vector2.new(barX, fillY)
        entry.HPFill.Size = Vector2.new(barW, fillH)
        entry.HPFill.Color = HealthColor(hpRatio)
        entry.HPFill.Visible = true

        if Config.ESP.HealthText and hp < maxHp * 0.99 then
            entry.HPText.Text = tostring(math.ceil(hp))
            entry.HPText.Position = Vector2.new(barX - 4 - entry.HPText.TextBounds.X, fillY - 6)
            entry.HPText.Color = HealthColor(hpRatio)
            entry.HPText.Visible = true
        else
            entry.HPText.Visible = false
        end
    else
        entry.HPBack.Visible = false
        entry.HPFill.Visible = false
        entry.HPText.Visible = false
    end

    if Config.ESP.Name then
        entry.NameText.Text = opts.label
        entry.NameText.Position = Vector2.new(x + w * 0.5, y - 16)
        entry.NameText.Color = opts.textColor or Config.ESP.Colors.Text
        entry.NameText.Visible = true
    else
        entry.NameText.Visible = false
    end

    local subParts = {}
    if Config.ESP.Weapon then
        local wName = GetEquippedWeaponName(char)
        if wName then table.insert(subParts, wName) end
    end
    if Config.ESP.Distance then
        local meters = math.floor(distStuds * METRES_PER_STUD + 0.5)
        table.insert(subParts, tostring(meters) .. "m")
    end
    if #subParts > 0 then
        entry.SubText.Text = table.concat(subParts, " · ")
        entry.SubText.Position = Vector2.new(x + w * 0.5, y + h + 2)
        entry.SubText.Visible = true
    else
        entry.SubText.Visible = false
    end
end

local function UpdatePlayerESP(player, entry)
    if not Config.ESP.Enabled or player == LocalPlayer then
        HideESPEntry(entry)
        return
    end
    local char = player.Character
    if not char then
        HideESPEntry(entry)
        return
    end
    local hp, maxHp, hasHealth = GetModelHealth(char, false)
    if not hasHealth or hp <= 0 or char:GetAttribute("Dead") == true then
        HideESPEntry(entry)
        return
    end
    local teammate = IsTeammate(player)
    if (Config.ESP.TeamCheck or not Config.ESP.ShowTeammates) and teammate then
        HideESPEntry(entry)
        return
    end
    local downed = IsDowned(char)
    if Config.ESP.IgnoreDowned and downed then
        HideESPEntry(entry)
        return
    end

    local head = char:FindFirstChild("Head")
    local mainColor
    if downed then
        mainColor = Config.ESP.Colors.Downed
    elseif teammate then
        mainColor = Config.ESP.Colors.Teammate
    elseif head and IsPartVisible(head, char) then
        mainColor = Config.ESP.Colors.EnemyVisible
    else
        mainColor = Config.ESP.Colors.Enemy
    end

    local label = player.DisplayName ~= "" and player.DisplayName or player.Name
    if downed then label = label .. " [DOWN]" end

    RenderModelESP(entry, char, {
        mainColor = mainColor,
        skelColor = downed and Config.ESP.Colors.SkeletonDowned or Config.ESP.Colors.Skeleton,
        textColor = downed and Config.ESP.Colors.Downed or Config.ESP.Colors.Text,
        label = label,
        hp = hp,
        maxHp = maxHp,
        hasHealth = true,
    })
end

local function UpdateEntityESP(model, info)
    local entry = info.entry
    if not Config.ESP.Enabled or not model or not model.Parent then
        HideESPEntry(entry)
        return
    end

    if info.kind == "Bot" then
        if not Config.ESP.ShowBots then
            HideESPEntry(entry)
            return
        end
        local hp, maxHp, hasHealth = GetModelHealth(model, false)
        if not hasHealth or hp <= 0 or model:GetAttribute("Dead") == true then
            HideESPEntry(entry)
            return
        end
        local head = model:FindFirstChild("Head")
        local visible = head and IsPartVisible(head, model)
        local baseName = (model.Name ~= "" and model.Name ~= "Scientist") and model.Name or "Scientist"
        RenderModelESP(entry, model, {
            mainColor = visible and Config.ESP.Colors.BotVisible or Config.ESP.Colors.Bot,
            skelColor = Config.ESP.Colors.SkeletonBot,
            textColor = Config.ESP.Colors.BotVisible,
            label = baseName .. " [BOT]",
            hp = hp,
            maxHp = maxHp,
            hasHealth = true,
        })
    elseif info.kind == "Sleeper" then
        if not Config.ESP.ShowSleepers then
            HideESPEntry(entry)
            return
        end
        local sleeperUid = model:GetAttribute("SleeperUserId")
        if sleeperUid == LocalPlayer.UserId then
            HideESPEntry(entry)
            return
        end
        local teammate = IsTeammateUserId(sleeperUid)
        if (Config.ESP.TeamCheck or not Config.ESP.ShowTeammates) and teammate then
            HideESPEntry(entry)
            return
        end
        local hp, maxHp, hasHealth = GetModelHealth(model, true)
        if (hasHealth and hp <= 0) or model:GetAttribute("Dead") == true then
            HideESPEntry(entry)
            return
        end
        local rawName = string.gsub(model.Name, " %(sleeping%)$", "")
        if rawName == "" then rawName = "Sleeper" end
        local color = teammate and Config.ESP.Colors.Teammate or Config.ESP.Colors.Sleeper
        RenderModelESP(entry, model, {
            mainColor = color,
            skelColor = Config.ESP.Colors.SkeletonSleeper,
            textColor = color,
            label = rawName .. " [SLEEP]",
            hp = hp,
            maxHp = maxHp,
            hasHealth = hasHealth,
        })
    end
end

-- ============================================================================
-- AIMBOT + BALLISTICS (MOBILE + PC)
-- ============================================================================
local FOVCircleOutline = NewDraw("Circle", {
    Visible = false, Filled = false, Thickness = 2.5, NumSides = 64, Color = Config.ESP.Colors.Outline,
})

local FOVCircle = NewDraw("Circle", {
    Visible = false, Filled = false, Thickness = 1.2, NumSides = 64, Color = Config.Aimbot.FOVColor,
})

local SilentSnapline = NewDraw("Line", {
    Visible = false, Thickness = 1.2, Transparency = 0.7, Color = Color3.fromRGB(255, 255, 255),
})

local SilentState = {
    Active = false,
    Part = nil,
    Char = nil,
    SuppressedClaims = {},
    LastBowDraw = 1,
    BowCalibration = nil, -- { baseSpeed, gravity, drag }
}

local PredictAimPosition

local function GetBowBallistics(draw)
    local d = math.clamp(type(draw) == "number" and draw or 1, 0.3, 1)
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    local ammoType = tool and (tool:GetAttribute("AmmoItem") or tool:GetAttribute("AmmoType"))
    local mult = (type(ammoType) == "string" and AMMO_SPEED_MULT[ammoType]) or 1

    if SilentState.BowCalibration then
        local cal = SilentState.BowCalibration
        return math.max(60, cal.baseSpeed * d * mult), cal.gravity, cal.drag
    end

    local speedAttr = tool and (tool:GetAttribute("ArrowSpeed") or tool:GetAttribute("BulletSpeed") or tool:GetAttribute("Speed"))
    local baseSpeed = (type(speedAttr) == "number" and speedAttr > 0) and speedAttr or 220
    local gravAttr = tool and (tool:GetAttribute("BulletGravity") or tool:GetAttribute("Gravity"))
    local gravity = (type(gravAttr) == "number" and gravAttr >= 0) and gravAttr or 40
    return math.max(60, baseSpeed * d * mult), gravity, 0
end

local function PredictBowDirection(origin, part, char, draw)
    local targetPos = part.Position
    local speed, gravity, drag = GetBowBallistics(draw)
    local vel = Config.Aimbot.Prediction and GetSmoothedVelocity(char, part) or Vector3.zero

    local t = math.min((targetPos - origin).Magnitude / speed, 1.8)
    local aimPos = targetPos
    for _ = 1, 4 do
        aimPos = targetPos + vel * t
        if not Config.Aimbot.GravityComp then
            t = math.min((aimPos - origin).Magnitude / speed, 1.8)
        elseif drag > 0.001 then
            local term = Vector3.new(0, -gravity / drag, 0)
            local expTerm = math.max(1 - math.exp(-drag * t), 0.001)
            local reqV0 = (aimPos - origin - term * t) * drag / expTerm + term
            t = math.min((aimPos - origin).Magnitude / math.max(reqV0.Magnitude, speed * 0.4), 1.8)
        else
            local dropPos = aimPos + Vector3.new(0, 0.5 * gravity * t * t, 0)
            t = math.min((dropPos - origin).Magnitude / speed, 1.8)
        end
    end

    if not Config.Aimbot.GravityComp then
        return (aimPos - origin).Unit
    elseif drag > 0.001 then
        local term = Vector3.new(0, -gravity / drag, 0)
        local expTerm = math.max(1 - math.exp(-drag * t), 0.001)
        local v0 = (aimPos - origin - term * t) * drag / expTerm + term
        return v0.Unit
    else
        local dropPos = aimPos + Vector3.new(0, 0.5 * gravity * t * t, 0)
        return (dropPos - origin).Unit
    end
end

local function BindBowFlightListener()
    task.spawn(function()
        local rs = game:GetService("ReplicatedStorage")
        local bowRem = rs:FindFirstChild("BowRemotes") or rs:WaitForChild("BowRemotes", 10)
        if not bowRem then return end
        local flight = bowRem:FindFirstChild("Flight") or bowRem:WaitForChild("Flight", 10)
        if not flight or not flight:IsA("RemoteEvent") then return end
        AddConn(flight.OnClientEvent:Connect(function(p1, p2)
            local data = (typeof(p1) == "number" and typeof(p2) == "table") and p2 or nil
            if not data then return end
            if typeof(data.pos) ~= "Vector3" or typeof(data.vel) ~= "Vector3" then return end
            if Camera and (data.pos - Camera.CFrame.Position).Magnitude <= 18 then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                local ammoType = tool and (tool:GetAttribute("AmmoItem") or tool:GetAttribute("AmmoType"))
                local mult = (type(ammoType) == "string" and AMMO_SPEED_MULT[ammoType]) or 1
                local draw = math.clamp(SilentState.LastBowDraw or 1, 0.3, 1)
                SilentState.BowCalibration = {
                    baseSpeed = data.vel.Magnitude / math.max(draw * mult, 0.1),
                    gravity = type(data.gravity) == "number" and data.gravity or 40,
                    drag = type(data.drag) == "number" and data.drag or 0,
                }
            end
        end))
    end)
end

local function InstallSilentHook()
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        return
    end

    local wrap = type(newcclosure) == "function" and newcclosure or function(f) return f end
    local sharedRegistry = getgenv and getgenv() or _G

    local function silentHandler(oldNamecall, self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and Config.Aimbot.SilentAim and SilentState.Active then
            local part = SilentState.Part
            local char = SilentState.Char
            if part and part.Parent and char and char.Parent and typeof(self) == "Instance" then
                local name = self.Name
                local remFolder = self.Parent
                local folderName = remFolder and remFolder.Name or ""

                if name == "Fire" or name == "Launch" then
                    local argc = select("#", ...)
                    local args = { ... }

                    -- Bow / Crossbow / Blowpipe / Speargun: BowRemotes.Fire(dir, draw, hold, claim) or Launch(dir, claim)
                    if (folderName == "BowRemotes" or (typeof(args[1]) == "Vector3" and typeof(args[2]) ~= "Vector3")) and typeof(args[1]) == "Vector3" then
                        if math.random(1, 100) <= Config.Aimbot.SilentHitChance then
                            local draw = (name == "Fire" and type(args[2]) == "number") and math.clamp(args[2], 0.3, 1) or 1
                            SilentState.LastBowDraw = draw
                            local claim = (name == "Fire") and args[4] or args[2]
                            local origin = (type(claim) == "table" and typeof(claim.o) == "Vector3") and claim.o or Camera.CFrame.Position
                            args[1] = PredictBowDirection(origin, part, char, draw)
                            return oldNamecall(self, table.unpack(args, 1, argc))
                        end

                    -- Firearms / PipePistol / DoubleBarrel: Fire(origin, dir, ...)
                    elseif typeof(args[1]) == "Vector3" and typeof(args[2]) == "Vector3" then
                        if math.random(1, 100) <= Config.Aimbot.SilentHitChance then
                            local origin = args[1]
                            local aimPos = PredictAimPosition(part, char)
                            args[2] = (aimPos - origin).Unit

                            local claim = args[4]
                            if type(claim) == "table" and type(claim.id) == "number" then
                                local hitRemote = remFolder and remFolder:FindFirstChild("Hit")
                                if hitRemote and hitRemote:IsA("RemoteEvent") then
                                    SilentState.SuppressedClaims[claim.id] = os.clock() + 3
                                    local speed = select(1, GetWeaponBallistics())
                                    local delaySec = math.clamp((aimPos - origin).Magnitude / math.max(100, speed), 0.01, 0.75)
                                    local targetPart, targetChar = part, char
                                    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                                    local pellets = (tool and tonumber(tool:GetAttribute("C_Pellets"))) or 1
                                    pellets = math.clamp(math.floor(pellets), 1, 12)
                                    task.delay(delaySec, function()
                                        if targetPart.Parent and targetChar.Parent and hitRemote.Parent then
                                            local nowT = Workspace:GetServerTimeNow()
                                            for pIdx = 1, pellets do
                                                hitRemote:FireServer(claim.id, pIdx, targetPart, targetPart.Position, nowT)
                                            end
                                        end
                                    end)
                                end
                            end
                            return oldNamecall(self, table.unpack(args, 1, argc))
                        end
                    end

                elseif name == "Hit" then
                    local claimId = ...
                    local exp = SilentState.SuppressedClaims[claimId]
                    if exp and os.clock() < exp then
                        return nil
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end

    -- Avoid stacking hookmetamethod across re-executions
    if sharedRegistry._OcelSilentHook then
        sharedRegistry._OcelSilentHook.handler = silentHandler
        sharedRegistry._OcelSilentHook.enabled = true
        return
    end

    local state = { handler = silentHandler, enabled = true }
    sharedRegistry._OcelSilentHook = state

    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", wrap(function(self, ...)
            if state.enabled and not checkcaller() then
                return state.handler(old, self, ...)
            end
            return old(self, ...)
        end))
    end)
    if not ok then
        sharedRegistry._OcelSilentHook = nil
    end
end

local function IsAimActive()
    if not Config.Aimbot.Enabled then
        return false
    end
    local mode = Config.Aimbot.TriggerMode
    if mode == "Always" then
        return true
    elseif mode == "Button" then
        if Config.Aimbot.ButtonMode == "Toggle" then
            return AimButtonToggled
        end
        return AimButtonHeld
    else -- "ADS": works on Mobile ADS (TouchAiming / MouseDeltaSensitivity) AND PC RMB
        if shared.TouchAiming == true or UserInputService.MouseDeltaSensitivity < 0.98 then
            return true
        end
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            return true
        end
        return AimButtonHeld
    end
end

local function ResolveTargetPart(character, screenCenter)
    local mode = Config.Aimbot.TargetPart
    if mode ~= "Closest" then
        return character:FindFirstChild(mode)
            or character:FindFirstChild("Head")
            or character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
    end

    local bestPart = nil
    local bestDist = math.huge
    for _, pName in ipairs({ "Head", "UpperTorso", "Torso", "LowerTorso" }) do
        local p = character:FindFirstChild(pName)
        if p and p:IsA("BasePart") then
            local sp, z = ProjectPoint(p.Position)
            if z > 0.2 then
                local d = (sp - screenCenter).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestPart = p
                end
            end
        end
    end
    return bestPart
end

local function IsValidAimCharacter(char, screenCenter, fovRadius, allowNoHumanoid)
    if not char or not char.Parent then return nil end
    local hp, _, hasHealth = GetModelHealth(char, allowNoHumanoid)
    if (hasHealth and hp <= 0) or char:GetAttribute("Dead") == true then return nil end
    if Config.Aimbot.IgnoreDowned and IsDowned(char) then return nil end

    local part = ResolveTargetPart(char, screenCenter)
    if not part then return nil end

    local distStuds = (part.Position - Camera.CFrame.Position).Magnitude
    if distStuds > Config.Aimbot.MaxDistance then return nil end

    local sp, z = ProjectPoint(part.Position)
    if z <= 0.2 then return nil end

    local screenDist = (sp - screenCenter).Magnitude
    if screenDist > fovRadius then return nil end

    if Config.Aimbot.VisibilityCheck and not IsPartVisible(part, char) then
        return nil
    end

    return part, char, screenDist
end

local function IsValidTargetEntry(target, screenCenter, fovRadius)
    if not target then return nil end
    if target:IsA("Player") then
        if not Config.Aimbot.TargetPlayers or target == LocalPlayer then return nil end
        if Config.Aimbot.TeamCheck and IsTeammate(target) then return nil end
        return IsValidAimCharacter(target.Character, screenCenter, fovRadius, false)
    elseif target:IsA("Model") then
        local info = EntityPool[target]
        if not info then return nil end
        if info.kind == "Bot" then
            if not Config.Aimbot.TargetBots then return nil end
            return IsValidAimCharacter(target, screenCenter, fovRadius, false)
        elseif info.kind == "Sleeper" then
            if not Config.Aimbot.TargetSleepers then return nil end
            local sleeperUid = target:GetAttribute("SleeperUserId")
            if sleeperUid == LocalPlayer.UserId then return nil end
            if Config.Aimbot.TeamCheck and IsTeammateUserId(sleeperUid) then return nil end
            return IsValidAimCharacter(target, screenCenter, fovRadius, true)
        end
    end
    return nil
end

PredictAimPosition = function(part, char)
    local targetPos = part.Position
    if not Config.Aimbot.Prediction and not Config.Aimbot.GravityComp then
        return targetPos
    end

    local origin = Camera.CFrame.Position
    local speed, gravity = GetWeaponBallistics()
    local vel = Config.Aimbot.Prediction and GetSmoothedVelocity(char, part) or Vector3.zero

    -- 3-pass time-of-flight & drop solver (matches v_u_279 kinematics: p0 + v*t - 0.5*g*t^2)
    local t = math.min((targetPos - origin).Magnitude / speed, 1.35)
    for _ = 1, 3 do
        local predicted = targetPos
        if Config.Aimbot.Prediction then
            predicted = predicted + vel * t
        end
        if Config.Aimbot.GravityComp then
            predicted = predicted + Vector3.new(0, 0.5 * gravity * t * t, 0)
        end
        t = math.min((predicted - origin).Magnitude / speed, 1.35)
    end

    local finalPos = targetPos
    if Config.Aimbot.Prediction then
        finalPos = finalPos + vel * t
    end
    if Config.Aimbot.GravityComp then
        finalPos = finalPos + Vector3.new(0, 0.5 * gravity * t * t, 0)
    end
    return finalPos
end

local function PickAimTarget(screenCenter)
    if Config.Aimbot.StickyTarget and LockedTarget and LockedTarget.Parent then
        local part, char = IsValidTargetEntry(LockedTarget, screenCenter, Config.Aimbot.FOV * 1.5)
        if part then
            return LockedTarget, part, char
        end
    end
    LockedTarget = nil

    local bestTarget, bestPart, bestChar = nil, nil, nil
    local bestScore = math.huge

    if Config.Aimbot.TargetPlayers then
        for _, player in ipairs(Players:GetPlayers()) do
            local part, char, screenDist = IsValidTargetEntry(player, screenCenter, Config.Aimbot.FOV)
            if part and screenDist < bestScore then
                bestScore = screenDist
                bestTarget = player
                bestPart = part
                bestChar = char
            end
        end
    end

    if Config.Aimbot.TargetBots or Config.Aimbot.TargetSleepers then
        for model, _ in pairs(EntityPool) do
            local part, char, screenDist = IsValidTargetEntry(model, screenCenter, Config.Aimbot.FOV)
            if part and screenDist < bestScore then
                bestScore = screenDist
                bestTarget = model
                bestPart = part
                bestChar = char
            end
        end
    end

    LockedTarget = bestTarget
    return bestTarget, bestPart, bestChar
end

local function StepAimbot(dt)
    local vp = Camera.ViewportSize
    local screenCenter = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local anyAimOn = Config.Aimbot.Enabled or Config.Aimbot.SilentAim

    if anyAimOn and Config.Aimbot.ShowFOV then
        FOVCircleOutline.Position = screenCenter
        FOVCircleOutline.Radius = Config.Aimbot.FOV
        FOVCircleOutline.Visible = true

        FOVCircle.Position = screenCenter
        FOVCircle.Radius = Config.Aimbot.FOV
        FOVCircle.Color = Config.Aimbot.FOVColor
        FOVCircle.Visible = true
    else
        FOVCircleOutline.Visible = false
        FOVCircle.Visible = false
    end

    local _, part, char = nil, nil, nil
    if anyAimOn then
        _, part, char = PickAimTarget(screenCenter)
    end

    -- Silent Aim state updates continuously whenever SilentAim is enabled
    if Config.Aimbot.SilentAim and part and char then
        SilentState.Active = true
        SilentState.Part = part
        SilentState.Char = char
        if Config.Aimbot.SilentSnapline then
            local sp, z = ProjectPoint(part.Position)
            if z > 0.2 then
                SilentSnapline.From = screenCenter
                SilentSnapline.To = sp
                SilentSnapline.Visible = true
            else
                SilentSnapline.Visible = false
            end
        else
            SilentSnapline.Visible = false
        end
    else
        SilentState.Active = false
        SilentState.Part = nil
        SilentState.Char = nil
        SilentSnapline.Visible = false
    end

    if not IsAimActive() then
        if not Config.Aimbot.SilentAim then
            LockedTarget = nil
        end
        AimHasLock = false
        return
    end

    if not part or not char then
        AimHasLock = false
        return
    end

    AimHasLock = true
    local aimWorld = PredictAimPosition(part, char)
    local camCF = Camera.CFrame
    if (aimWorld - camCF.Position).Magnitude < 0.5 then
        return
    end

    local targetCF = CFrame.lookAt(camCF.Position, aimWorld)
    local dot = math.clamp(camCF.LookVector:Dot(targetCF.LookVector), -1, 1)
    local angle = math.acos(dot)

    if angle < 1e-5 then
        return
    end

    local alpha
    if Config.Aimbot.Smoothness <= 1.05 then
        alpha = 1
    else
        local baseAlpha = 1 - math.exp(-(60 / Config.Aimbot.Smoothness) * dt * 0.55)
        if angle < 0.035 then
            baseAlpha = math.max(baseAlpha, 0.55)
        end
        alpha = math.clamp(baseAlpha, 0.06, 1)
    end

    local maxRad = math.rad(Config.Aimbot.MaxDegPerSec) * dt
    if angle * alpha > maxRad then
        alpha = math.clamp(maxRad / angle, 0.02, 1)
    end

    local nextCF = camCF:Lerp(targetCF, alpha)
    Camera.CFrame = nextCF

    -- Keep SmoothLookAim synced for AimWatchLook consistency
    if type(shared.SmoothLookAim) == "table" then
        local lv = nextCF.LookVector
        shared.SmoothLookAim.yaw = math.atan2(-lv.X, -lv.Z)
        shared.SmoothLookAim.pitch = math.asin(math.clamp(lv.Y, -1, 1))
        shared.SmoothLookAim.at = os.clock()
    end
end

-- ============================================================================
-- OCEL-HUB MONOCHROME UI (MOBILE + PC)
-- ============================================================================
local Theme = {
    Bg = Color3.fromRGB(11, 11, 13),
    Surface = Color3.fromRGB(19, 19, 22),
    SurfaceHover = Color3.fromRGB(28, 28, 33),
    Border = Color3.fromRGB(48, 48, 56),
    Accent = Color3.fromRGB(255, 255, 255),
    AccentMuted = Color3.fromRGB(155, 155, 165),
    Text = Color3.fromRGB(246, 246, 248),
    TextDim = Color3.fromRGB(145, 145, 155),
    Track = Color3.fromRGB(38, 38, 44),
}

local GuiRoot = Instance.new("ScreenGui")
GuiRoot.Name = "OcelHub"
GuiRoot.ResetOnSpawn = false
GuiRoot.IgnoreGuiInset = true
GuiRoot.DisplayOrder = 999

local function MountGui()
    local ok = pcall(function()
        if type(gethui) == "function" then
            GuiRoot.Parent = gethui()
        else
            GuiRoot.Parent = CoreGui
        end
    end)
    if not ok or not GuiRoot.Parent then
        GuiRoot.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end
MountGui()

-- Draggable helper (multi-touch safe: tracks exact Touch InputObject)
local function MakeDraggable(handle, target, onTap)
    local activeInput, moved, dragStart, startPos = nil, false, nil, nil
    AddConn(handle.InputBegan:Connect(function(input)
        if not activeInput and IsPointerDownInput(input) then
            activeInput = input
            moved = false
            dragStart = input.Position
            startPos = target.Position
        end
    end))
    AddConn(UserInputService.InputChanged:Connect(function(input)
        if not activeInput then return end
        local sameTouch = (activeInput.UserInputType == Enum.UserInputType.Touch and input == activeInput)
        local mouseMove = (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
        if sameTouch or mouseMove then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then
                moved = true
            end
            if moved then
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end))
    AddConn(UserInputService.InputEnded:Connect(function(input)
        if activeInput and input == activeInput then
            activeInput = nil
            if not moved and onTap then
                onTap()
            end
        end
    end))
end

-- Floating OCEL pill (always accessible on mobile!)
local TogglePill = Instance.new("TextButton")
TogglePill.Size = UDim2.fromOffset(78, 30)
TogglePill.Position = UDim2.new(0, 14, 0, 58)
TogglePill.BackgroundColor3 = Theme.Bg
TogglePill.BorderSizePixel = 0
TogglePill.Font = Enum.Font.GothamBold
TogglePill.TextSize = 12
TogglePill.TextColor3 = Theme.Accent
TogglePill.Text = "OCEL"
TogglePill.AutoButtonColor = false
TogglePill.Parent = GuiRoot
Instance.new("UICorner", TogglePill).CornerRadius = UDim.new(1, 0)
local PillStroke = Instance.new("UIStroke", TogglePill)
PillStroke.Color = Theme.Accent
PillStroke.Thickness = 1.2
PillStroke.Transparency = 0.35

-- Floating AIM button (shown when TriggerMode == "Button")
local AimFloatBtn = Instance.new("TextButton")
AimFloatBtn.Size = UDim2.fromOffset(64, 64)
AimFloatBtn.Position = UDim2.new(1, -92, 0.56, -32)
AimFloatBtn.BackgroundColor3 = Theme.Bg
AimFloatBtn.BackgroundTransparency = 0.2
AimFloatBtn.BorderSizePixel = 0
AimFloatBtn.Font = Enum.Font.GothamBold
AimFloatBtn.TextSize = 13
AimFloatBtn.TextColor3 = Theme.Accent
AimFloatBtn.Text = "AIM"
AimFloatBtn.AutoButtonColor = false
AimFloatBtn.Visible = Config.Aimbot.Enabled and Config.Aimbot.TriggerMode == "Button"
AimFloatBtn.Parent = GuiRoot
Instance.new("UICorner", AimFloatBtn).CornerRadius = UDim.new(1, 0)
local AimFloatStroke = Instance.new("UIStroke", AimFloatBtn)
AimFloatStroke.Color = Theme.Border
AimFloatStroke.Thickness = 1.8

do
    local dragStart, startPos, moved, activeInput = nil, nil, false, nil
    AddConn(AimFloatBtn.InputBegan:Connect(function(input)
        if not activeInput and IsPointerDownInput(input) then
            activeInput = input
            dragStart = input.Position
            startPos = AimFloatBtn.Position
            moved = false
            if Config.Aimbot.ButtonMode == "Hold" then
                AimButtonHeld = true
            end
        end
    end))
    AddConn(UserInputService.InputChanged:Connect(function(input)
        if not activeInput then return end
        local sameTouch = (activeInput.UserInputType == Enum.UserInputType.Touch and input == activeInput)
        local mouseMove = (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
        if sameTouch or mouseMove then
            local delta = input.Position - dragStart
            if delta.Magnitude > 14 then
                moved = true
                AimFloatBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end))
    AddConn(UserInputService.InputEnded:Connect(function(input)
        if activeInput and input == activeInput then
            activeInput = nil
            AimButtonHeld = false
            if not moved and Config.Aimbot.ButtonMode == "Toggle" then
                AimButtonToggled = not AimButtonToggled
            end
        end
    end))
end

-- Main Ocel-hub Panel
local Panel = Instance.new("Frame")
Panel.Size = IsMobile and UDim2.fromOffset(310, 390) or UDim2.fromOffset(320, 440)
Panel.Position = IsMobile and UDim2.new(0.5, -155, 0.5, -195) or UDim2.new(0, 20, 0.5, -220)
Panel.BackgroundColor3 = Theme.Bg
Panel.BorderSizePixel = 0
Panel.Visible = Config.UI.Open
Panel.Parent = GuiRoot
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)
local PanelStroke = Instance.new("UIStroke", Panel)
PanelStroke.Color = Theme.Border
PanelStroke.Thickness = 1

MakeDraggable(TogglePill, TogglePill, function()
    Config.UI.Open = not Config.UI.Open
    Panel.Visible = Config.UI.Open
end)

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 38)
Header.BackgroundColor3 = Theme.Surface
Header.BorderSizePixel = 0
Header.Parent = Panel
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 10)

local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, 10)
HeaderCover.Position = UDim2.new(0, 0, 1, -10)
HeaderCover.BackgroundColor3 = Theme.Surface
HeaderCover.BorderSizePixel = 0
HeaderCover.Parent = Header

local BrandTitle = Instance.new("TextLabel")
BrandTitle.Size = UDim2.new(0.55, 0, 1, 0)
BrandTitle.Position = UDim2.fromOffset(14, 0)
BrandTitle.BackgroundTransparency = 1
BrandTitle.Font = Enum.Font.GothamBold
BrandTitle.TextSize = 14
BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
BrandTitle.TextColor3 = Theme.Accent
BrandTitle.Text = "OCEL-HUB"
BrandTitle.Parent = Header

local SubBrand = Instance.new("TextLabel")
SubBrand.Size = UDim2.new(0.3, 0, 1, 0)
SubBrand.Position = UDim2.fromOffset(88, 1)
SubBrand.BackgroundTransparency = 1
SubBrand.Font = Enum.Font.Gotham
SubBrand.TextSize = 10
SubBrand.TextXAlignment = Enum.TextXAlignment.Left
SubBrand.TextColor3 = Theme.TextDim
SubBrand.Text = IsMobile and "MOBILE" or "DESKTOP"
SubBrand.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(24, 24)
CloseBtn.Position = UDim2.new(1, -32, 0.5, -12)
CloseBtn.BackgroundColor3 = Theme.Track
CloseBtn.BorderSizePixel = 0
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Theme.Text
CloseBtn.Text = "—"
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
AddConn(CloseBtn.MouseButton1Click:Connect(function()
    Config.UI.Open = false
    Panel.Visible = false
end))

local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.fromOffset(54, 24)
UnloadBtn.Position = UDim2.new(1, -92, 0.5, -12)
UnloadBtn.BackgroundColor3 = Theme.Track
UnloadBtn.BorderSizePixel = 0
UnloadBtn.Font = Enum.Font.GothamSemibold
UnloadBtn.TextSize = 10
UnloadBtn.TextColor3 = Theme.TextDim
UnloadBtn.Text = "UNLOAD"
UnloadBtn.Parent = Header
Instance.new("UICorner", UnloadBtn).CornerRadius = UDim.new(0, 6)

MakeDraggable(Header, Panel, nil)

-- Divider
local Divider = Instance.new("Frame")
Divider.Size = UDim2.new(1, 0, 0, 1)
Divider.Position = UDim2.fromOffset(0, 38)
Divider.BackgroundColor3 = Theme.Border
Divider.BorderSizePixel = 0
Divider.Parent = Panel

-- Tab Bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 30)
TabBar.Position = UDim2.fromOffset(10, 46)
TabBar.BackgroundColor3 = Theme.Surface
TabBar.BorderSizePixel = 0
TabBar.Parent = Panel
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 7)

local ESPTabPage = Instance.new("ScrollingFrame")
ESPTabPage.Size = UDim2.new(1, -20, 1, -92)
ESPTabPage.Position = UDim2.fromOffset(10, 84)
ESPTabPage.BackgroundTransparency = 1
ESPTabPage.BorderSizePixel = 0
ESPTabPage.ScrollBarThickness = 2
ESPTabPage.ScrollBarImageColor3 = Theme.AccentMuted
ESPTabPage.CanvasSize = UDim2.fromOffset(0, 0)
ESPTabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
ESPTabPage.Parent = Panel

local AimTabPage = Instance.new("ScrollingFrame")
AimTabPage.Size = ESPTabPage.Size
AimTabPage.Position = ESPTabPage.Position
AimTabPage.BackgroundTransparency = 1
AimTabPage.BorderSizePixel = 0
AimTabPage.ScrollBarThickness = 2
AimTabPage.ScrollBarImageColor3 = Theme.AccentMuted
AimTabPage.CanvasSize = UDim2.fromOffset(0, 0)
AimTabPage.AutomaticCanvasSize = Enum.AutomaticSize.Y
AimTabPage.Visible = false
AimTabPage.Parent = Panel

for _, page in ipairs({ ESPTabPage, AimTabPage }) do
    local list = Instance.new("UIListLayout", page)
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder
end

local function MakeTabButton(text, xScale, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.49, 0, 1, -4)
    btn.Position = UDim2.new(xScale, 2, 0, 2)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Text = text
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    AddConn(btn.MouseButton1Click:Connect(onClick))
    return btn
end

local TabBtnESP, TabBtnAim
local function SelectTab(which)
    local isESP = (which == "ESP")
    ESPTabPage.Visible = isESP
    AimTabPage.Visible = not isESP
    TabBtnESP.BackgroundColor3 = isESP and Theme.Accent or Theme.Surface
    TabBtnESP.TextColor3 = isESP and Theme.Bg or Theme.TextDim
    TabBtnAim.BackgroundColor3 = (not isESP) and Theme.Accent or Theme.Surface
    TabBtnAim.TextColor3 = (not isESP) and Theme.Bg or Theme.TextDim
end

TabBtnESP = MakeTabButton("ESP", 0, function() SelectTab("ESP") end)
TabBtnAim = MakeTabButton("AIMBOT", 0.5, function() SelectTab("AIM") end)
SelectTab("ESP")

local function SyncAimFloatVisibility()
    AimFloatBtn.Visible = Config.Aimbot.Enabled and Config.Aimbot.TriggerMode == "Button"
end

local function AddToggle(parent, label, getVal, setVal)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -4, 0, 34)
    row.BackgroundColor3 = Theme.Surface
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Theme.Text
    lbl.Text = label
    lbl.Parent = row

    local pill = Instance.new("Frame")
    pill.Size = UDim2.fromOffset(34, 18)
    pill.Position = UDim2.new(1, -44, 0.5, -9)
    pill.BorderSizePixel = 0
    pill.Parent = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12, 12)
    knob.BorderSizePixel = 0
    knob.Parent = pill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function sync()
        local on = getVal()
        pill.BackgroundColor3 = on and Theme.Accent or Theme.Track
        knob.BackgroundColor3 = on and Theme.Bg or Theme.TextDim
        knob.Position = on and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3)
    end
    sync()

    AddConn(row.MouseButton1Click:Connect(function()
        setVal(not getVal())
        sync()
    end))
end

local function AddCycle(parent, label, options, getVal, setVal)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -4, 0, 34)
    row.BackgroundColor3 = Theme.Surface
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Position = UDim2.fromOffset(12, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Theme.Text
    lbl.Text = label
    lbl.Parent = row

    local badge = Instance.new("TextLabel")
    badge.Size = UDim2.fromOffset(88, 22)
    badge.Position = UDim2.new(1, -98, 0.5, -11)
    badge.BackgroundColor3 = Theme.Track
    badge.BorderSizePixel = 0
    badge.Font = Enum.Font.GothamBold
    badge.TextSize = 11
    badge.TextColor3 = Theme.Accent
    badge.Text = tostring(getVal())
    badge.Parent = row
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 5)

    AddConn(row.MouseButton1Click:Connect(function()
        local cur = getVal()
        local idx = 1
        for i, v in ipairs(options) do
            if v == cur then idx = i break end
        end
        local nextVal = options[(idx % #options) + 1]
        setVal(nextVal)
        badge.Text = tostring(nextVal)
    end))
end

local function AddSlider(parent, label, minV, maxV, step, getVal, setVal)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(1, -4, 0, 44)
    box.BackgroundColor3 = Theme.Surface
    box.BorderSizePixel = 0
    box.Parent = parent
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 7)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.68, 0, 0, 20)
    lbl.Position = UDim2.fromOffset(12, 4)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextColor3 = Theme.Text
    lbl.Text = label
    lbl.Parent = box

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.28, -12, 0, 20)
    valLbl.Position = UDim2.new(0.72, 0, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.TextColor3 = Theme.Accent
    valLbl.Parent = box

    local track = Instance.new("TextButton")
    track.Size = UDim2.new(1, -24, 0, 10)
    track.Position = UDim2.fromOffset(12, 26)
    track.BackgroundColor3 = Theme.Track
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = box
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local function sync()
        local v = getVal()
        local ratio = math.clamp((v - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        valLbl.Text = string.format(step < 1 and "%.1f" or "%d", v)
    end
    sync()

    local activeInput = nil
    local function applyX(px)
        local ratio = math.clamp((px - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        local raw = minV + (maxV - minV) * ratio
        local snapped = math.floor(raw / step + 0.5) * step
        setVal(math.clamp(snapped, minV, maxV))
        sync()
    end

    AddConn(track.InputBegan:Connect(function(input)
        if not activeInput and IsPointerDownInput(input) then
            activeInput = input
            applyX(input.Position.X)
        end
    end))
    AddConn(UserInputService.InputChanged:Connect(function(input)
        if not activeInput then return end
        local sameTouch = (activeInput.UserInputType == Enum.UserInputType.Touch and input == activeInput)
        local mouseMove = (activeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)
        if sameTouch or mouseMove then
            applyX(input.Position.X)
        end
    end))
    AddConn(UserInputService.InputEnded:Connect(function(input)
        if activeInput and input == activeInput then
            activeInput = nil
        end
    end))
end

-- Populate ESP tab
AddToggle(ESPTabPage, "ESP Enabled", function() return Config.ESP.Enabled end, function(v) Config.ESP.Enabled = v end)
AddToggle(ESPTabPage, "Boxes", function() return Config.ESP.Box end, function(v) Config.ESP.Box = v end)
AddCycle(ESPTabPage, "Box Style", { "Corners", "Full" }, function() return Config.ESP.BoxStyle end, function(v) Config.ESP.BoxStyle = v end)
AddToggle(ESPTabPage, "Box Fill", function() return Config.ESP.BoxFill end, function(v) Config.ESP.BoxFill = v end)
AddToggle(ESPTabPage, "Skeletons", function() return Config.ESP.Skeleton end, function(v) Config.ESP.Skeleton = v end)
AddSlider(ESPTabPage, "Skeleton Min Height (px)", 12, 80, 2, function() return Config.ESP.SkeletonMinHeight end, function(v) Config.ESP.SkeletonMinHeight = v end)
AddToggle(ESPTabPage, "Head Dot", function() return Config.ESP.HeadDot end, function(v) Config.ESP.HeadDot = v end)
AddToggle(ESPTabPage, "Names & Status", function() return Config.ESP.Name end, function(v) Config.ESP.Name = v end)
AddToggle(ESPTabPage, "Distance (m)", function() return Config.ESP.Distance end, function(v) Config.ESP.Distance = v end)
AddToggle(ESPTabPage, "Held Weapon", function() return Config.ESP.Weapon end, function(v) Config.ESP.Weapon = v end)
AddToggle(ESPTabPage, "HP Bar", function() return Config.ESP.HealthBar end, function(v) Config.ESP.HealthBar = v end)
AddToggle(ESPTabPage, "Show Bots (Scientists)", function() return Config.ESP.ShowBots end, function(v) Config.ESP.ShowBots = v end)
AddToggle(ESPTabPage, "Show Sleepers", function() return Config.ESP.ShowSleepers end, function(v) Config.ESP.ShowSleepers = v end)
AddToggle(ESPTabPage, "Show Teammates", function() return Config.ESP.ShowTeammates end, function(v) Config.ESP.ShowTeammates = v end)
AddSlider(ESPTabPage, "Max Distance (studs)", 200, 2500, 50, function() return Config.ESP.MaxDistance end, function(v) Config.ESP.MaxDistance = v end)

-- Populate Aimbot tab
AddToggle(AimTabPage, "Silent Aim", function() return Config.Aimbot.SilentAim end, function(v) Config.Aimbot.SilentAim = v end)
AddToggle(AimTabPage, "Silent Snapline", function() return Config.Aimbot.SilentSnapline end, function(v) Config.Aimbot.SilentSnapline = v end)
AddSlider(AimTabPage, "Silent Hit Chance (%)", 10, 100, 5, function() return Config.Aimbot.SilentHitChance end, function(v) Config.Aimbot.SilentHitChance = v end)
AddToggle(AimTabPage, "Aimbot Enabled", function() return Config.Aimbot.Enabled end, function(v)
    Config.Aimbot.Enabled = v
    SyncAimFloatVisibility()
end)
AddCycle(AimTabPage, "Aim Trigger", { "Button", "ADS", "Always" }, function() return Config.Aimbot.TriggerMode end, function(v)
    Config.Aimbot.TriggerMode = v
    AimButtonHeld = false
    AimButtonToggled = false
    SyncAimFloatVisibility()
end)
AddCycle(AimTabPage, "Aim Button Mode", { "Hold", "Toggle" }, function() return Config.Aimbot.ButtonMode end, function(v)
    Config.Aimbot.ButtonMode = v
    AimButtonHeld = false
    AimButtonToggled = false
end)
AddCycle(AimTabPage, "Target Bone", { "Head", "UpperTorso", "Closest", "LowerTorso" }, function() return Config.Aimbot.TargetPart end, function(v) Config.Aimbot.TargetPart = v end)
AddToggle(AimTabPage, "Target Players", function() return Config.Aimbot.TargetPlayers end, function(v) Config.Aimbot.TargetPlayers = v end)
AddToggle(AimTabPage, "Target Bots", function() return Config.Aimbot.TargetBots end, function(v) Config.Aimbot.TargetBots = v end)
AddToggle(AimTabPage, "Target Sleepers", function() return Config.Aimbot.TargetSleepers end, function(v) Config.Aimbot.TargetSleepers = v end)
AddToggle(AimTabPage, "Show FOV Circle", function() return Config.Aimbot.ShowFOV end, function(v) Config.Aimbot.ShowFOV = v end)
AddSlider(AimTabPage, "FOV Radius (px)", 30, 450, 5, function() return Config.Aimbot.FOV end, function(v) Config.Aimbot.FOV = v end)
AddSlider(AimTabPage, "Smoothness (1=snap)", 1, 16, 0.5, function() return Config.Aimbot.Smoothness end, function(v) Config.Aimbot.Smoothness = v end)
AddSlider(AimTabPage, "Max Turn (deg/s)", 200, 1500, 25, function() return Config.Aimbot.MaxDegPerSec end, function(v) Config.Aimbot.MaxDegPerSec = v end)
AddToggle(AimTabPage, "Visibility Check", function() return Config.Aimbot.VisibilityCheck end, function(v) Config.Aimbot.VisibilityCheck = v end)
AddToggle(AimTabPage, "Team Check", function() return Config.Aimbot.TeamCheck end, function(v) Config.Aimbot.TeamCheck = v end)
AddToggle(AimTabPage, "Ignore Downed", function() return Config.Aimbot.IgnoreDowned end, function(v) Config.Aimbot.IgnoreDowned = v end)
AddToggle(AimTabPage, "Ballistic Prediction", function() return Config.Aimbot.Prediction end, function(v) Config.Aimbot.Prediction = v end)
AddToggle(AimTabPage, "Bullet Drop Comp", function() return Config.Aimbot.GravityComp end, function(v) Config.Aimbot.GravityComp = v end)
AddToggle(AimTabPage, "Sticky Target", function() return Config.Aimbot.StickyTarget end, function(v) Config.Aimbot.StickyTarget = v end)

-- ============================================================================
-- LIFECYCLE & RENDER STEP
-- ============================================================================
local function EnsurePlayerESP(player)
    if player ~= LocalPlayer and not ESPPool[player] then
        ESPPool[player] = CreateESPEntry()
    end
end

local function EnsureEntityESP(model, kind)
    if model and model:IsA("Model") and not EntityPool[model] then
        EntityPool[model] = { entry = CreateESPEntry(), kind = kind }
    end
end

local function RemoveEntityESP(model)
    local info = EntityPool[model]
    if info then
        DestroyESPEntry(info.entry)
        EntityPool[model] = nil
    end
    VelocityCache[model] = nil
    if LockedTarget == model then
        LockedTarget = nil
    end
end

local function BindFolder(folder, kind)
    for _, child in ipairs(folder:GetChildren()) do
        EnsureEntityESP(child, kind)
    end
    AddConn(folder.ChildAdded:Connect(function(child)
        EnsureEntityESP(child, kind)
    end))
    AddConn(folder.ChildRemoved:Connect(function(child)
        RemoveEntityESP(child)
    end))
end

local function WatchEntityFolder(folderName, kind)
    local existing = Workspace:FindFirstChild(folderName)
    if existing then
        BindFolder(existing, kind)
    end
    AddConn(Workspace.ChildAdded:Connect(function(child)
        if child.Name == folderName then
            BindFolder(child, kind)
        end
    end))
end

for _, p in ipairs(Players:GetPlayers()) do
    EnsurePlayerESP(p)
end

AddConn(Players.PlayerAdded:Connect(EnsurePlayerESP))
AddConn(Players.PlayerRemoving:Connect(function(player)
    local entry = ESPPool[player]
    if entry then
        DestroyESPEntry(entry)
        ESPPool[player] = nil
    end
    if LockedTarget == player then
        LockedTarget = nil
    end
end))

WatchEntityFolder("Scientists", "Bot")
WatchEntityFolder("Sleepers", "Sleeper")

RefreshTeammates()
AddConn(LocalPlayer:GetAttributeChangedSignal("TeamMates"):Connect(RefreshTeammates))

AddConn(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera
end))

AddConn(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Config.UI.ToggleKey or input.KeyCode == Config.UI.AltToggleKey then
        Config.UI.Open = not Config.UI.Open
        Panel.Visible = Config.UI.Open
    end
end))

InstallSilentHook()
BindBowFlightListener()

-- Bind at Last - 1 so CameraModule & SmoothLookPost run first and AimWatchLook runs after
local STEP_NAME = "OcelHubRenderStep"
RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Last.Value - 1, function(dt)
    Camera = Workspace.CurrentCamera
    if not Camera then return end

    for player, entry in pairs(ESPPool) do
        if player.Parent == Players then
            UpdatePlayerESP(player, entry)
        else
            HideESPEntry(entry)
        end
    end

    for model, info in pairs(EntityPool) do
        if model.Parent then
            UpdateEntityESP(model, info)
        else
            RemoveEntityESP(model)
        end
    end

    StepAimbot(dt)

    if AimFloatBtn.Visible then
        local active = IsAimActive()
        AimFloatBtn.BackgroundColor3 = active and Theme.Accent or Theme.Bg
        AimFloatBtn.TextColor3 = active and Theme.Bg or Theme.Accent
        AimFloatStroke.Color = AimHasLock and Color3.fromRGB(90, 230, 130) or (active and Theme.Accent or Theme.Border)
    end
end)

local function Unload()
    local sharedRegistry = getgenv and getgenv() or _G
    if sharedRegistry._OcelSilentHook then
        sharedRegistry._OcelSilentHook.enabled = false
    end

    pcall(function() RunService:UnbindFromRenderStep(STEP_NAME) end)
    for _, conn in ipairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Connections)

    for _, entry in pairs(ESPPool) do
        DestroyESPEntry(entry)
    end
    table.clear(ESPPool)

    for _, info in pairs(EntityPool) do
        DestroyESPEntry(info.entry)
    end
    table.clear(EntityPool)
    table.clear(VelocityCache)

    pcall(function() FOVCircleOutline:Remove() end)
    pcall(function() FOVCircle:Remove() end)
    pcall(function() SilentSnapline:Remove() end)
    pcall(function() GuiRoot:Destroy() end)

    if getgenv and getgenv()._OcelHubUnload == Unload then
        getgenv()._OcelHubUnload = nil
    end
end

if getgenv then
    getgenv()._OcelHubUnload = Unload
end
AddConn(UnloadBtn.MouseButton1Click:Connect(Unload))
