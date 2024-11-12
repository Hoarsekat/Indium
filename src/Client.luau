type Middleware = {
	Inbound: ClientMiddleware?,
	Outbound: ClientMiddleware?,
}

type ClientMiddlewareFn = (args: { any }) -> (boolean, ...any)

type ClientMiddleware = { ClientMiddlewareFn }

type PerServiceMiddleware = { [string]: Middleware }

type ControllerDef = {
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
	Middleware: Middleware?,
	PerServiceMiddleware: PerServiceMiddleware?,
}

local defaultOptions: IndiumOptions = {
	ServicePromises = true,
	Middleware = nil,
	PerServiceMiddleware = {},
}

local selectedOptions = nil

local IndiumClient = {}

IndiumClient.Player = game:GetService("Players").LocalPlayer

IndiumClient.Util = (script.Parent :: Instance).Parent

local Promise = require(IndiumClient.Util.Promise)
local Comm = require(IndiumClient.Util.Comm)
local ClientComm = Comm.ClientComm

local controllers: { [string]: Controller } = {}
local services: { [string]: Service } = {}
local servicesFolder = nil

local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")

local function DoesControllerExist(controllerName: string): boolean
	local controller: Controller? = controllers[controllerName]

	return controller ~= nil
end

local function GetServicesFolder()
	if not servicesFolder then
		servicesFolder = (script.Parent :: Instance):WaitForChild("Services")
	end

	return servicesFolder
end

local function GetMiddlewareForService(serviceName: string)
	local IndiumMiddleware = if selectedOptions.Middleware ~= nil then selectedOptions.Middleware else {}
	local serviceMiddleware = selectedOptions.PerServiceMiddleware[serviceName]

	return if serviceMiddleware ~= nil then serviceMiddleware else IndiumMiddleware
end

local function BuildService(serviceName: string)
	local folder = GetServicesFolder()
	local middleware = GetMiddlewareForService(serviceName)
	local clientComm = ClientComm.new(folder, selectedOptions.ServicePromises, serviceName)
	local service = clientComm:BuildObject(middleware.Inbound, middleware.Outbound)

	services[serviceName] = service

	return service
end

function IndiumClient.CreateController(controllerDef: ControllerDef): Controller
	assert(type(controllerDef) == "table", `Controller must be a table; got {type(controllerDef)}`)
	assert(type(controllerDef.Name) == "string", `Controller.Name must be a string; got {type(controllerDef.Name)}`)
	assert(#controllerDef.Name > 0, "Controller.Name must be a non-empty string")
	assert(not DoesControllerExist(controllerDef.Name), `Controller {controllerDef.Name} already exists`)
	assert(not started, `Controllers cannot be created after calling "Indium.Start()"`)

	local controller = controllerDef :: Controller
	controllers[controller.Name] = controller

	return controller
end

function IndiumClient.AddControllers(parent: Instance): { Controller }
	assert(not started, `Controllers cannot be added after calling "Indium.Start()"`)

	local addedControllers = {}
	for _, v in parent:GetChildren() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

function IndiumClient.AddControllersDeep(parent: Instance): { Controller }
	assert(not started, `Controllers cannot be added after calling "Indium.Start()"`)

	local addedControllers = {}
	for _, v in parent:GetDescendants() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedControllers, require(v))
	end

	return addedControllers
end

function IndiumClient.GetService(serviceName: string): Service
	local service = services[serviceName]
	if service then
		return service
	end

	assert(started, "Cannot call GetService until Indium has been started")
	assert(type(serviceName) == "string", `ServiceName must be a string; got {type(serviceName)}`)

	return BuildService(serviceName)
end

function IndiumClient.GetController(controllerName: string): Controller
	local controller = controllers[controllerName]
	if controller then
		return controller
	end

	assert(started, "Cannot call GetController until Indium has been started")
	assert(type(controllerName) == "string", `ControllerName must be a string; got {type(controllerName)}`)
	error(`Could not find controller "{controllerName}". Check to verify a controller with this name exists.`, 2)
end

function IndiumClient.GetControllers(): { [string]: Controller }
	assert(started, "Cannot call GetControllers until Indium has been started")

	return controllers
end

function IndiumClient.Start(options: IndiumOptions?)
	if started then
		return Promise.reject("Indium already started")
	end

	started = true

	table.freeze(controllers)

	if options == nil then
		selectedOptions = defaultOptions
	else
		assert(typeof(options) == "table", `IndiumOptions should be a table or nil; got {typeof(options)}`)
		selectedOptions = options
		for k, v in defaultOptions do
			if selectedOptions[k] == nil then
				selectedOptions[k] = v
			end
		end
	end
	if type(selectedOptions.PerServiceMiddleware) ~= "table" then
		selectedOptions.PerServiceMiddleware = {}
	end

	return Promise.new(function(resolve)
		local promisesStartControllers = {}

		for _, controller in controllers do
			if type(controller.IndiumInit) == "function" then
				table.insert(
					promisesStartControllers,
					Promise.new(function(r)
						debug.setmemorycategory(controller.Name)
						controller:IndiumInit()
						r()
					end)
				)
			end
		end

		resolve(Promise.all(promisesStartControllers))
	end):andThen(function()
		for _, controller in controllers do
			if type(controller.IndiumStart) == "function" then
				task.spawn(function()
					debug.setmemorycategory(controller.Name)
					controller:IndiumStart()
				end)
			end
		end

		startedComplete = true
		onStartedComplete:Fire()

		task.defer(function()
			onStartedComplete:Destroy()
		end)
	end)
end

function IndiumClient.OnStart()
	if startedComplete then
		return Promise.resolve()
	else
		return Promise.fromEvent(onStartedComplete.Event)
	end
end

return IndiumClient
