local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Indium = require(ReplicatedStorage.Packages.Indium)

Indium.AddControllers(script.Controllers)

Indium.Start()
	:andThen(function()
		print("Indium started on the client!")
	end)
	:catch(warn)
