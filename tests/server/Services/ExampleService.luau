local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Indium = require(ReplicatedStorage.Packages.Indium)

local ExampleService = Indium.CreateService({
	Name = "ExampleService",
	Client = {},
})

function ExampleService:PrintStatement()
	print("I printed a statement!")
end

function ExampleService.Client:PrintStatement()
	return self.Server:PrintStatement()
end

function ExampleService:IndiumInit()
	print(self.Name, "has initialized!")
end

return ExampleService
