type Middleware = {
	Inbound: ServerMiddleware?,
	Outbound: ServerMiddleware?,
}

type ServerMiddlewareFn = (player: Player, args: { any }) -> (boolean, ...any)

type ServerMiddleware = { ServerMiddlewareFn }

type ServiceDef = {
	Name: string,
	Client: { [any]: any }?,
	Middleware: Middleware?,
	[any]: any,
}

type Service = {
	Name: string,
	Client: ServiceClient,
	IndiumComm: any,
	[any]: any,
}

type ServiceClient = {
	Server: Service,
	[any]: any,
}

type IndiumOptions = {
	Middleware: Middleware?,
}

local defaultOptions: IndiumOptions = {
	Middleware = nil,
}

local selectedOptions = nil

local IndiumServer = {}

IndiumServer.Util = (script.Parent :: Instance).Parent

local SIGNAL_MARKER = newproxy(true)
getmetatable(SIGNAL_MARKER).__tostring = function()
	return "SIGNAL_MARKER"
end

local UNRELIABLE_SIGNAL_MARKER = newproxy(true)
getmetatable(UNRELIABLE_SIGNAL_MARKER).__tostring = function()
	return "UNRELIABLE_SIGNAL_MARKER"
end

local PROPERTY_MARKER = newproxy(true)
getmetatable(PROPERTY_MARKER).__tostring = function()
	return "PROPERTY_MARKER"
end

local IndiumRepServiceFolder = Instance.new("Folder")
IndiumRepServiceFolder.Name = "Services"

local Promise = require(IndiumServer.Util.Promise)
local Comm = require(IndiumServer.Util.Comm)
local ServerComm = Comm.ServerComm

local services: { [string]: Service } = {}
local started = false
local startedComplete = false
local onStartedComplete = Instance.new("BindableEvent")

local function DoesServiceExist(serviceName: string): boolean
	local service: Service? = services[serviceName]

	return service ~= nil
end

function IndiumServer.CreateService(serviceDef: ServiceDef): Service
	assert(type(serviceDef) == "table", `Service must be a table; got {type(serviceDef)}`)
	assert(type(serviceDef.Name) == "string", `Service.Name must be a string; got {type(serviceDef.Name)}`)
	assert(#serviceDef.Name > 0, "Service.Name must be a non-empty string")
	assert(not DoesServiceExist(serviceDef.Name), `Service "{serviceDef.Name}" already exists`)
	assert(not started, `Services cannot be created after calling "Indium.Start()"`)

	local service = serviceDef
	service.IndiumComm = ServerComm.new(IndiumRepServiceFolder, serviceDef.Name)

	if type(service.Client) ~= "table" then
		service.Client = { Server = service }
	else
		if service.Client.Server ~= service then
			service.Client.Server = service
		end
	end

	services[service.Name] = service

	return service
end

function IndiumServer.AddServices(parent: Instance): { Service }
	assert(not started, `Services cannot be added after calling "Indium.Start()"`)

	local addedServices = {}
	for _, v in parent:GetChildren() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedServices, require(v))
	end

	return addedServices
end

function IndiumServer.AddServicesDeep(parent: Instance): { Service }
	assert(not started, `Services cannot be added after calling "Indium.Start()"`)

	local addedServices = {}
	for _, v in parent:GetDescendants() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(addedServices, require(v))
	end

	return addedServices
end

function IndiumServer.GetService(serviceName: string): Service
	assert(started, "Cannot call GetService until Indium has been started")
	assert(type(serviceName) == "string", `ServiceName must be a string; got {type(serviceName)}`)

	return assert(services[serviceName], `Could not find service "{serviceName}"`) :: Service
end

function IndiumServer.GetServices(): { [string]: Service }
	assert(started, "Cannot call GetServices until Indium has been started")

	return services
end

function IndiumServer.CreateSignal()
	return SIGNAL_MARKER
end

function IndiumServer.CreateUnreliableSignal()
	return UNRELIABLE_SIGNAL_MARKER
end

function IndiumServer.CreateProperty(initialValue: any)
	return { PROPERTY_MARKER, initialValue }
end

function IndiumServer.Start(options: IndiumOptions?)
	if started then
		return Promise.reject("Indium already started")
	end

	started = true

	table.freeze(services)

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

	return Promise.new(function(resolve)
		local IndiumMiddleware = if selectedOptions.Middleware ~= nil then selectedOptions.Middleware else {}

		for _, service in services do
			local middleware = if service.Middleware ~= nil then service.Middleware else {}
			local inbound = if middleware.Inbound ~= nil then middleware.Inbound else IndiumMiddleware.Inbound
			local outbound = if middleware.Outbound ~= nil then middleware.Outbound else IndiumMiddleware.Outbound

			service.Middleware = nil

			for k, v in service.Client do
				if type(v) == "function" then
					service.IndiumComm:WrapMethod(service.Client, k, inbound, outbound)
				elseif v == SIGNAL_MARKER then
					service.Client[k] = service.IndiumComm:CreateSignal(k, false, inbound, outbound)
				elseif v == UNRELIABLE_SIGNAL_MARKER then
					service.Client[k] = service.IndiumComm:CreateSignal(k, true, inbound, outbound)
				elseif type(v) == "table" and v[1] == PROPERTY_MARKER then
					service.Client[k] = service.IndiumComm:CreateProperty(k, v[2], inbound, outbound)
				end
			end
		end

		local promisesInitServices = {}
		for _, service in services do
			if type(service.IndiumInit) == "function" then
				table.insert(
					promisesInitServices,
					Promise.new(function(r)
						debug.setmemorycategory(service.Name)
						service:IndiumInit()
						r()
					end)
				)
			end
		end

		resolve(Promise.all(promisesInitServices))
	end):andThen(function()
		for _, service in services do
			if type(service.IndiumStart) == "function" then
				task.spawn(function()
					debug.setmemorycategory(service.Name)
					service:IndiumStart()
				end)
			end
		end

		startedComplete = true
		onStartedComplete:Fire()

		task.defer(function()
			onStartedComplete:Destroy()
		end)

		IndiumRepServiceFolder.Parent = script.Parent
	end)
end

function IndiumServer.OnStart()
	if startedComplete then
		return Promise.resolve()
	else
		return Promise.fromEvent(onStartedComplete.Event)
	end
end

return IndiumServer
