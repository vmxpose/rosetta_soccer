--!nonstrict
-- Tiny in-house test harness for lune. A spec module is `function(t)` calling t.case(name, fn);
-- assertions error on failure and the case is recorded. No external dependencies.

local Harness = {}

local function deepEquals(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEquals(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

export type Context = {
	case: (name: string, fn: () -> ()) -> (),
	ok: (condition: any, message: string?) -> (),
	eq: (actual: any, expected: any, message: string?) -> (),
	near: (actual: number, expected: number, epsilon: number, message: string?) -> (),
	fails: (fn: () -> (), message: string?) -> (),
	passed: number,
	failed: number,
	failures: { string },
}

function Harness.newContext(specName: string): Context
	local t = {}
	t.passed = 0
	t.failed = 0
	t.failures = {}

	function t.case(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if ok then
			t.passed += 1
		else
			t.failed += 1
			table.insert(t.failures, `{specName} > {name}: {tostring(err)}`)
		end
	end

	function t.ok(condition: any, message: string?)
		if not condition then
			error(message or "expected truthy value", 2)
		end
	end

	function t.eq(actual: any, expected: any, message: string?)
		if not deepEquals(actual, expected) then
			error(`{message or "not equal"} — actual: {tostring(actual)}, expected: {tostring(expected)}`, 2)
		end
	end

	function t.near(actual: number, expected: number, epsilon: number, message: string?)
		if math.abs(actual - expected) > epsilon then
			error(`{message or "not near"} — actual: {actual}, expected: {expected} ± {epsilon}`, 2)
		end
	end

	function t.fails(fn: () -> (), message: string?)
		local ok = pcall(fn)
		if ok then
			error(message or "expected function to error", 2)
		end
	end

	return t
end

return Harness
