--[[
	VWeatherStationReport — Roblox module (Direction 2)
	Reports your game's CURRENT in-game weather/state TO VWeatherStation, so
	players can view your server's live weather on a public dashboard page —
	the same idea as the GTA V weather station.

	This is the REVERSE of VWeatherConnect (which pulls real weather INTO your
	game). Use this when you want your game's weather shown on the website.

	INSTALL:
	  1. ModuleScript named "VWeatherStationReport" in ServerScriptService.
	  2. Enable HTTP: Game Settings -> Security -> Allow HTTP Requests.
	  3. Server Script:

	     local Report = require(game.ServerScriptService.VWeatherStationReport)
	     local session = Report.Start({ serverName = "My Cool Server" })
	     -- when your game's weather changes, tell us:
	     Report.Update({
	         weather = "rain",       -- clear|cloudy|rain|storm|snow|fog
	         gameTime = "14:30",     -- your in-game clock
	         zone = "Downtown",      -- optional area name
	         temperature = 18,       -- optional, your game's temp
	     })

	  On first Start(), the module prints a PAIRING CODE + a dashboard URL.
	  Share the dashboard URL so players can watch your server's weather live.
]]

local HttpService = game:GetService("HttpService")
local API = "https://vweatherstation.com/api/v1"

local VWeatherStationReport = {}
local state = { sessionToken = nil, manageToken = nil, pairingCode = nil }

local function post(path, body)
	local ok, res = pcall(function()
		return HttpService:PostAsync(API .. path, HttpService:JSONEncode(body), Enum.HttpContentType.ApplicationJson)
	end)
	if not ok then warn("[VWeatherStationReport] " .. tostring(res)); return nil end
	local ok2, decoded = pcall(function() return HttpService:JSONDecode(res) end)
	return ok2 and decoded or nil
end

function VWeatherStationReport.Start(config)
	config = config or {}
	local resp = post("/game-sessions/", {
		game = "roblox",
		mode = config.serverName or "Roblox Server",
		platform = "roblox",
	})
	if resp and resp.session_token then
		state.sessionToken = resp.session_token
		state.manageToken = resp.manage_token
		state.pairingCode = resp.pairing_code
		print("========================================")
		print("[VWeatherStation] Roblox server connected!")
		print("Pairing code: " .. tostring(resp.pairing_code))
		print("Dashboard: https://vweatherstation.com/games/roblox/live/?s=" .. tostring(resp.manage_token))
		print("Share that dashboard URL with your players.")
		print("========================================")
	else
		warn("[VWeatherStationReport] failed to start session")
	end
	return state
end

function VWeatherStationReport.Update(data)
	if not state.sessionToken then return end
	data = data or {}
	post("/game-telemetry/", {
		session_token = state.sessionToken,
		game_time = data.gameTime or "",
		weather = data.weather or "clear",
		raw_weather = data.weather or "clear",
		zone = data.zone or "",
		temperature = data.temperature,
		players = data.players,
	})
end

return VWeatherStationReport
