--!strict
-- Runner self-test: deliberately failing. Proves a failing test exits non-zero.
return {
	["equal fails on different values"] = function(t)
		t.equal(1 + 1, 3)
	end,
}
