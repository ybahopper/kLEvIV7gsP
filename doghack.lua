local bESP = true
local lp = LocalPlayer()

local fov = 25
local smooth = 20 -- 0-100
local lead = .01 -- Seconds

local buddies = {
	["76561198362949858"] = true,
	["76561198152847871"] = true,
	["76561199136462605"] = true,
	["76561199512228343"] = true
}

local actualSmooth = 100 - smooth

local scrw, scrh = ScrW(), ScrH()
local cx, cy = scrw / 2, scrh / 2

local color_dormant = Color(255, 0, 0)

local function isVisible(ent)
	local tr = util.TraceLine({
		start = lp:EyePos(),
		endpos = ent:GetPos() + ent:OBBCenter(),
		mask = MASK_SHOT,
		filter = {lp, ent}
	})

	return not tr.Hit
end

local function predict_pos(ply)
	return ply:GetPos() + ply:GetVelocity() * lead
end

local function get_closest_target()
	local closest, bestDist
	for _, ply in ipairs(player.GetAll()) do
		if ply == lp then continue end
		if ply:Team() == TEAM_STAFFONDUTY then continue end -- Don't lock on staff
		if buddies[ply:SteamID64()] then continue end -- Don't lock on buddies
		if not ply:Alive() then continue end

		local pos = ply:GetPos() + ply:OBBCenter()
		local ts = pos:ToScreen()

		if not ts.visible then continue end
		if not isVisible(ply) then continue end

		local dx, dy = ts.x - cx, ts.y - cy
		local dist2D = math.sqrt(dx * dx + dy * dy)

		local radius = (fov / lp:GetFOV()) * (scrw / 2)
		if dist2D <= radius and (not bestDist or dist2D < bestDist) then
			closest, bestDist = ply, dist2D
		end
	end

	return closest
end

local function aim_at_target(target)
	if not target then return end

	local targetPos = predict_pos(target) + target:OBBCenter()
	local aimPos = (targetPos - lp:GetShootPos()):Angle()

	local curAng = lp:EyeAngles()

	local t = 1 - math.exp(-actualSmooth * FrameTime())

	local newAng = LerpAngle(t, curAng, aimPos)
	newAng.roll = 0
	lp:SetEyeAngles(newAng)
end

local function DrawOverlay()
	for _, ply in ipairs(player.GetAll()) do
		if lp == ply then continue end
		if ply:IsDormant() then continue end
		if not ply:Alive() then continue end

		local pos = ply:GetPos() + ply:OBBCenter()
		local ts = pos:ToScreen()
		if (ply:GetSuit() ~= "") then
			cam.Start3D()
				render.SuppressEngineLighting(true)
				ply:DrawModel()
				render.SuppressEngineLighting(false)
			cam.End3D()

			draw.SimpleText(ply:Nick(), "DermaDefault", ts.x, ts.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(ply:GetSuit(), "DermaDefault", ts.x, ts.y + 15, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(ply:GetSuitHealth(), "DermaDefault", ts.x, ts.y + 30, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end

		local radius = (fov / lp:GetFOV()) * (scrw / 2)

		surface.DrawCircle(ScrW() / 2, ScrH() / 2, radius, color_white)

		if not ts.visible then continue end

		local dx, dy = ts.x - cx, ts.y - cy
		local dist2D = math.sqrt(dx * dx + dy *dy)

		if input.IsMouseDown(MOUSE_5) then
			local target = get_closest_target()
			aim_at_target(target)
		end
	end
end

local SimpleThirdPerson = GetRenderTarget("STP", ScrW(), ScrH())
hook.Add("RenderScene", "DogHack::RenderScene", function(origin, angles, fov)
	if not bESP then return end
	local view = {
		x = 0,
		y = 0,
		w = ScrW(),
		h = ScrH(),
		dopostprocess = true,
		origin = origin,
		angles = angles,
		fov = fov,
		drawhud = true,
		drawmonitors = true,
		drawviewmodels = true
	}

	render.RenderView(view)
	render.CopyTexture(nil, SimpleThirdPerson)

	cam.Start2D()
		DrawOverlay()
	cam.End2D()

	render.SetRenderTarget(SimpleThirdPerson)
	return true
end)

concommand.Add("dog_esp", function()
	bESP = not bESP
end)