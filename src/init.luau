--!strict

local RunService = game:GetService("RunService")

local Client = require(script.Client)
local Server = require(script.Server)

return (if RunService:IsServer() then Server else Client) :: typeof(Server) & typeof(Client)
