---
description: >-
  Indium is a powerful, lightweight BDD-style game framework inspired by the
  likes of Knit and Weaver.
---

# Indium



### What does Indium have to offer?

The main "cool part" about Indium is the BDD-style structure inspired by Roblox's TestEZ library. Here is an example of the creation of an Indium service:

```lua
-- ExampleService.lua

-- // Services
local replicatedStorage = game:GetService("ReplicatedStorage")

-- // Directory
local packages = replicatedStorage.Packages
local indium = require(packages:WaitForChild("Indium"))

-- // Create a basic service
local service = indium.create.service({
    name: string = "ExampleService",
    client = {},
})

-- // Init function that is run on service creation
function service:__init()
    print(self.name, "has initialized!")
end

return service
```

Indium offers a toolset that includes components with tags, the creation of services and controllers, and the ability to setup middleware for your game. Indium also provides you with suggestions on how to structure your game's directory.

### Why use Indium over other frameworks like Knit or Weaver?

Indium has a few features which differs from other commonly used frameworks.

* Indium provides a component-based system with support for tags and attributes
* You can create and initialize a service at any time with full automation
* Indium uses a BDD-style codebase
* You can use `indium.get.service("service_name")` at any time, even from a non-controller or a non-service (such as a class/metatable), before Indium even starts! No more needing to use `Knit.OnStart()`!

### Ready to setup your framework?

Visit the setup section of the documentation to get started!

{% content-ref url="broken-reference" %}
[Broken link](broken-reference)
{% endcontent-ref %}
