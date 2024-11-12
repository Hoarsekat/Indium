-- TODO: Add support for creating services after being started
local Packages = (script.Parent :: Instance).Parent

local Comm = require(Packages.Comm)
local Promise = require(Packages.Promise)
local ServerComm = Comm.ServerComm

--[=[
    @interface Reference
    .Name string
    .Client table?
    .[any] any
    @within IndiumServer
    Acts as a reference to new services.
]=]
--
type Reference = {
	Name: string,
	Client: { [any]: any }?,
	[any]: any,
}

--[=[
    @interface Service
    .Name string
    .Client ServiceClient
    .Communication Comm
    .[any] any
    @within IndiumServer
]=]
--
type Service = {
	Name: string,
	Client: ServiceClient,
	Communication: any,
	[any]: any,
}

--[=[
    @interface ServiceClient
    .Server Service
    .[any] any
    @within IndiumServer
]=]
--
type ServiceClient = {
	Server: Service,
	[any]: any,
}

--[=[
    @class IndiumServer
    @server
    Allows for the creation of services and any bridges between client communication.

    ```lua
    local Indium = require(path.to.Indium)

    -- Requires and preloads modules within a specified folder:
    Indium.AddServices(path.to.Services)

    -- Starts the Indium server:
    Indium.Start():andThen(function()
        print("Indium has loaded on the server!")
    end):catch(warn)
    ```
]=]
--
local IndiumServer = {}

local CommFolder = Instance.new("Folder")
CommFolder.Name = "Services"

local Services: { [string]: Service } = {}
local Started = false
local StartedComplete = false
local OnStartedComplete = Instance.new("BindableEvent")

local function DoesServiceExist(ServiceName: string): boolean
	local service: Service? = Services[ServiceName]

	return service ~= nil
end

--[=[
    Creates and returns a new service.

    :::caution
    While creating a service after Indium starts is fine, it is heavily advised against.
    :::
    ```lua
    -- Create an example service
    local ExampleService = Indium.CreateService({
        Name = "ExampleService",
        Client = {},
    })

    -- IndiumStart is called after Indium is initialized
    function ExampleService:IndiumStart()
        print(self.Name, "has started!")
    end

    -- IndiumInit is called when Indium is first started
    function ExampleService:IndiumInit()
        print(self.Name, "has initialized!")
    end
    ```
]=]
--
function IndiumServer:CreateService(ref: Reference): Service
	assert(type(ref) == "table", `Service must be a table; got {type(ref)}`)
	assert(type(ref.Name) == "string", `Service.Name must be a string; got {type(ref.Name)}`)
	assert(#ref.Name > 0, "Service.Name must be a non-empty string")
	assert(not DoesServiceExist(ref.Name), `Service "{ref.Name}" already exists`)
	assert(not Started, `Services cannot be created after calling "Indium:Start()"`)

	local service = ref
	service.IndiumComm = ServerComm.new(CommFolder, ref.Name)

	if type(service.Client) ~= "table" then
		service.Client = { Server = service }
	else
		if service.Client.Server ~= service then
			service.Client.Server = service
		end
	end

	Services[service.Name] = service

	return service
end

--[=[
    Requires the descendants of the specified parent that are a module.
    ```lua
    Indium.AddServices(path.to.Services)
    ```
]=]
--
function IndiumServer:AddServices(Parent: Instance): { Service }
	assert(not Started, `Services cannot be added after calling "Indium:Start()"`)

	local AddedServices = {}

	for _, v in Parent:GetDescendants() do
		if not v:IsA("ModuleScript") then
			continue
		end

		table.insert(AddedServices, require(v))
	end

	return AddedServices
end

--[=[
    Gets the service from the name that is specified.
]=]
--
function IndiumServer:GetService(Name: string): Service
	assert(Started, "Cannot call GetService until Indium has been started")
	assert(type(Name) == "string", `Name must be a string; got {type(Name)}`)

	return assert(Services[Name], `Could not find service "{Name}"`) :: Service
end

--[=[
    @return Promise
    Starts Indium and should only be called once.

    You may create services _before_ and _after_ Indium starts.

    :::caution
    There is currently no option to add middleware.
    This feature will be added soon.
    :::

    ```lua
    Indium:Start():andThen(function()
        print("Indium started!")
    end):catch(warn)
    ```
]=]
--
function IndiumServer:Start()
	if Started then
		return Promise.reject("Indium has already started")
	end

	Started = true

	table.freeze(Services)

	return Promise.new(function(resolve)
		local PromisesInitServices = {}

		for _, service in Services do
			if type(service.IndiumInit) == "function" then
				table.insert(
					PromisesInitServices,
					Promise.new(function(res)
						debug.setmemorycategory(service.Name)
						service:IndiumInit()
						res()
					end)
				)
			end
		end

		resolve(Promise.all(PromisesInitServices))
	end):andThen(function()
		for _, service in Services do
			if type(service.IndiumStart) == "function" then
				task.spawn(function()
					debug.setmemorycategory(service.Name)
					service:IndiumStart()
				end)
			end
		end

		StartedComplete = true
		OnStartedComplete:Fire()

		task.defer(function()
			OnStartedComplete:Destroy()
		end)

		CommFolder.Parent = script.Parent
	end)
end

--[=[
    @return Promise
    Returns a promise that is resolved once Indium has started.
    ```lua
    Indium.OnStart():andThen(function()
        local ExampleService = Indium.Services.ExampleService
        ExampleService:DoSomething()
    end):catch(warn)
    ```
]=]
--
function IndiumServer.OnStart()
	if StartedComplete then
		return Promise.resolve()
	else
		return Promise.fromEvent(OnStartedComplete.Event)
	end
end

return IndiumServer
