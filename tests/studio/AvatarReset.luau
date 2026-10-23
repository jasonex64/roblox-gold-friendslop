--!strict
-- Server-only live avatar-reset regression; run while no production action is active.
local player = game.Players:GetPlayers()[1]
local server = game.ServerScriptService.Server
local character = player.Character
local pivot = character:GetPivot()
local before = server.GetDigState:Invoke(player)
local outputs = server.GetSiftState:Invoke(player)
local ledger = server.GetEconomyState:Invoke(player)
assert(not outputs.pending and not player:GetAttribute("Digging"))
local tools = {}
for _, parent in { player.Backpack, character } do
	for _, item in parent:GetChildren() do
		if item:IsA("Tool") then
			assert(not tools[item.Name], "duplicate starter tool")
			tools[item.Name] = item
		end
	end
end
local function equal(left, right)
	if type(left) ~= "table" then
		return left == right
	end
	if type(right) ~= "table" then
		return false
	end
	for key, value in left do
		if not equal(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end
character.Humanoid.Health = 0
local deadline = os.clock() + 15
repeat
	task.wait(0.1)
	assert(os.clock() < deadline, "avatar did not respawn with starter tools")
until player.Character ~= character
	and player.Character
	and player.Character:FindFirstChild("HumanoidRootPart")
	and player.Backpack:FindFirstChild("Shovel")
assert(
	equal(before, server.GetDigState:Invoke(player)),
	"reset changed batch identity/opening count"
)
assert(equal(outputs, server.GetSiftState:Invoke(player)), "reset changed completed inventory")
assert(equal(ledger, server.GetEconomyState:Invoke(player)), "reset changed money/upgrade")
for name, tool in tools do
	assert(player.Backpack:FindFirstChild(name) == tool, "reset regranted tool " .. name)
end
player.Character:PivotTo(pivot)
print(
	"[T011 DIG-2/3] real avatar death/reset preserves batch identities, opening count, completed finds, money/upgrade and SAME starter Tool instances"
)
return "Avatar reset regression passed; original position restored"
