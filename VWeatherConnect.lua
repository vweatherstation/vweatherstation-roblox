--[[
	VWeatherConnect — Roblox module
	Pulls real-world weather from VWeatherStation and reflects it in your game
	(sky, lighting, optional rain/snow). Free, no API key.

	INSTALL:
	  1. In Roblox Studio, create a ModuleScript in ServerScriptService named
	     "VWeatherConnect" and paste this code in.
	  2. Enable HTTP requests: Game Settings -> Security -> Allow HTTP Requests.
	  3. Create a Script (server) in ServerScriptService with:

	        local VW = require(game.ServerScriptService.VWeatherConnect)
	        VW.Start({
	            latitude = 40.71,     -- your real-world location
	            longitude = -74.01,
	            updateSeconds = 600,  -- how often to refresh (10 min)
	            controlLighting = true,
	        })

	  That's it — your game's weather now follows the real world.

	Data: vweatherstation.com/api/v1/game-weather
]]

local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local VWeatherConnect = {}
VWeatherConnect.__index = VWeatherConnect

local ENDPOINT = "https://vweatherstation.com/api/v1/game-weather"

-- current state other scripts can read: VWeatherConnect.Current
VWeatherConnect.Current = nil
-- a BindableEvent-style callback list for "weather changed"
local listeners = {}

function VWeatherConnect.OnWeatherChanged(fn)
	table.insert(listeners, fn)
end

local function fireListeners(data)
	for _, fn in ipairs(listeners) do
		task.spawn(fn, data)
	end
end

-- Map our condition -> simple Lighting look (tweak to taste in your game)
local function applyLighting(data)
	local cond = data.condition
	local isDay = data.is_day == 1

	-- clouds / fog density
	local fog = 0
	if cond == "fog" then fog = 350
	elseif cond == "overcast" then fog = 900
	elseif cond == "thunderstorm" then fog = 500
	elseif cond == "snow" then fog = 600
	elseif cond == "rain" then fog = 700 end
	Lighting.FogEnd = (fog == 0) and 100000 or fog

	-- brightness / tint by condition + day
	if not isDay then
		Lighting.Brightness = 0.4
		Lighting.OutdoorAmbient = Color3.fromRGB(40, 45, 60)
	elseif cond == "clear" then
		Lighting.Brightness = 3
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
	elseif cond == "cloudy" then
		Lighting.Brightness = 2
		Lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 135)
	elseif cond == "overcast" or cond == "rain" or cond == "drizzle" then
		Lighting.Brightness = 1.2
		Lighting.OutdoorAmbient = Color3.fromRGB(110, 112, 120)
	elseif cond == "thunderstorm" then
		Lighting.Brightness = 0.8
		Lighting.OutdoorAmbient = Color3.fromRGB(90, 92, 105)
	elseif cond == "snow" then
		Lighting.Brightness = 2.2
		Lighting.OutdoorAmbient = Color3.fromRGB(160, 165, 175)
	elseif cond == "fog" then
		Lighting.Brightness = 1.5
		Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 145)
	end

	-- set clock roughly to real day/night
	Lighting.ClockTime = isDay and 12 or 0
end

local function fetchOnce(cfg)
	local url = ENDPOINT .. "?lat=" .. cfg.latitude .. "&lon=" .. cfg.longitude
	local ok, res = pcall(function()
		return HttpService:GetAsync(url)
	end)
	if not ok then
		warn("[VWeatherConnect] request failed: " .. tostring(res))
		return
	end
	local data
	ok, data = pcall(function() return HttpService:JSONDecode(res) end)
	if not ok or not data or not data.ok then
		warn("[VWeatherConnect] bad response")
		return
	end
	VWeatherConnect.Current = data
	if cfg.controlLighting then
		pcall(applyLighting, data)
	end
	fireListeners(data)
end

function VWeatherConnect.Start(config)
	config = config or {}
	local cfg = {
		latitude = config.latitude or 51.51,
		longitude = config.longitude or -0.13,
		updateSeconds = math.max(120, config.updateSeconds or 600),
		controlLighting = config.controlLighting ~= false,
	}
	-- initial fetch, then loop
	task.spawn(function()
		fetchOnce(cfg)
		while true do
			task.wait(cfg.updateSeconds)
			fetchOnce(cfg)
		end
	end)
	return VWeatherConnect
end

return VWeatherConnect
