local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Indium = require(ReplicatedStorage.Packages.Indium)

local function Logger(player: Player, args: { any })
	print(player, args)
	return true
end

Indium.AddServices(script.Services)

Indium.Start({
	Middleware = { Inbound = { Logger } },
})
	:andThen(function()
		print("Indium started on the server!")
	end)
	:catch(warn)
