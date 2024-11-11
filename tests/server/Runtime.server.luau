local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Indium = require(ReplicatedStorage.Packages.Indium)

Indium.OnStart()
	:andThen(function()
		local ExampleService = Indium:GetService("ExampleService")
		ExampleService:PrintStatement()
	end)
	:catch(warn)
