--!strict
-- Runner self-test. `scripts/check` expects this suite to report 1 passed, 1 failed, exit 1.
return {
	["equal passes on equal values"] = function(t)
		t.equal(1 + 1, 2)
	end,
}
