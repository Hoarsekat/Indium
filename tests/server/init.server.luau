local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Indium = require(ReplicatedStorage.Packages.Indium)

Indium:AddServices(script.Services)

Indium:Start()
	:andThen(function()
		print("Indium started!")
	end)
	:catch(warn)
