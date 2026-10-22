--!strict
-- Client entry point. Boot line is what the Studio MCP smoke check looks for.
local Players = game:GetService("Players")

print("[client] boot ok", Players.LocalPlayer.Name)
