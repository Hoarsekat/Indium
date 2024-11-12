local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Indium = require(ReplicatedStorage.Packages.Indium)

local ExampleController = Indium.CreateController({
	Name = "ExampleController",
})

function ExampleController:IndiumInit()
	local ExampleService = Indium.GetService("ExampleService")
	ExampleService:PrintStatement()
end

return ExampleController
