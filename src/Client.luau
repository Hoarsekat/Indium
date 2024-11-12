local Packages = (script.Parent :: Instance).Parent

local Comm = require(Packages.Comm)
local Promise = require(Packages.Promise)
local ClientComm = Comm.ClientComm

type Reference = {
	Name: string,
	[any]: any,
}

type Controller = {
	Name: string,
	[any]: any,
}

type Service = {
	[any]: any,
}

type IndiumOptions = {
	ServicePromises: boolean,
}

local DefaultOptions = {
	ServicePromises = true,
}

local SelectedOptions = nil

local IndiumClient = {}

IndiumClient.Player = game:GetService("Players").LocalPlayer

local Controllers: { [string]: Controller } = {}
local Services: { [string]: Services } = {}
local ServicesFolder = nil

local Started = false
local StartedComplete = false
local OnStartedComplete = Instance.new("BindableEvent")

local function DoesControllerExist(Name: string): boolean
	local controller: Controller? = Controllers[Name]

	return controller ~= nil
end

local function GetServicesFolder()
	if not ServicesFolder then
		ServicesFolder = (script.Parent :: Instance):WaitForChild("Services")
	end

	return ServicesFolder
end

local function BuildService(Name: string)
	local Folder = GetServicesFolder()
	local clientComm = ClientComm.new(Folder, SelectedOptions.ServicePromises, Name)
	local Service = clientComm:BuildObject()

	Services[Name] = Service

	return Service
end

function IndiumClient:CreateController(ref: Reference): Controller
	assert(type(ref) == "table", `Controller must be a table; got {type(ref)}`)
	assert(type(ref.Name) == "string", `Controller.Name must be a string; got {type(ref.Name)}`)
	assert(#ref.Name > 0, "Controller.Name must be a non-empty string")
	assert(not DoesControllerExist(ref.Name), `Controller {ref.Name} already exists`)
	assert(not Started, `Controllers cannot be created after calling "Indium:Start()"`)

	local controller = ref :: Controller
	Controllers[controller.Name] = controller

	return controller
end

function IndiumClient:AddControllers(Parent: Instance): { Controller }
	assert(not Started, `Controllers cannot be added after calling "Indium:Start()"`)

	local AddedControllers = {}

	for _, v in Parent:GetDescendants() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(AddedControllers, require(v))
	end

	return AddedControllers
end

function IndiumClient:GetService(Name: string): Service
	local service = Services[Name]
	if service then
		return service
	end

	assert(Started, "Cannot call GetService until Indium has been started")
	assert(type(Name) == "string", `Name must be a string; got {type(Name)}`)

	return BuildService(Name)
end

function IndiumClient:GetController(Name: string): Controller
	local controller = Controllers[Name]
	if controller then
		return controller
	end

	assert(Started, "Cannot call GetController until Indium has been started")
	assert(type(Name) == "string", `ControllerName must be a string; got {type(Name)}`)
	error(`Could not find controller "{Name}". Check to verify a controller with this name exists.`, 2)
end

function IndiumClient:GetControllers(): { [string]: Controller }
	assert(Started, "Cannot call GetControllers until Indium has been started")

	return Controllers
end

function IndiumClient:Start(Options: IndiumOptions?)
	if Started then
		return Promise.reject("Indium already started")
	end

	Started = true

	table.freeze(Controllers)

	if Options == nil then
		SelectedOptions = DefaultOptions
	else
		assert(typeof(Options) == "table", `IndiumOptions should be a table or nil; got {typeof(Options)}`)
		SelectedOptions = Options
		for k, v in DefaultOptions do
			if SelectedOptions[k] == nil then
				SelectedOptions[k] = v
			end
		end
	end

	return Promise.new(function(resolve)
		local PromisesStartControllers = {}

		for _, controller in Controllers do
			if type(controller.IndiumInit) == "function" then
				table.insert(
					PromisesStartControllers,
					Promise.new(function(r)
						debug.setmemorycategory(controller.Name)
						controller:IndiumInit()
						r()
					end)
				)
			end
		end

		resolve(Promise.all(PromisesStartControllers))
	end):andThen(function()
		for _, controller in Controllers do
			if type(controller.IndiumStart) == "function" then
				task.spawn(function()
					debug.setmemorycategory(controller.Name)
					controller:IndiumStart()
				end)
			end
		end

		StartedComplete = true
		OnStartedComplete:Fire()

		task.defer(function()
			OnStartedComplete:Destroy()
		end)
	end)
end

function IndiumClient:OnStart()
	if StartedComplete then
		return Promise.resolve()
	else
		return Promise.fromEvent(OnStartedComplete.Event)
	end
end

return IndiumClient
