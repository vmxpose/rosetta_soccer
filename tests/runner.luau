--!nonstrict
-- Test runner: `lune run tests/runner`. Specs are registered statically; each gets a
-- fresh context. Exits non-zero on any failure.

local process = require("@lune/process")

local harness = require("./harness")

local specs: { [string]: (t: any) -> () } = {
	vector_parity = require("./specs/vector_parity_spec"),
	ecs = require("./specs/ecs_spec"),
	scheduler = require("./specs/scheduler_spec"),
	protocol = require("./specs/protocol_spec"),
	clock = require("./specs/clock_spec"),
	sequencer = require("./specs/sequencer_spec"),
	collision = require("./specs/collision_spec"),
}

local names = {}
for name in specs do
	table.insert(names, name)
end
table.sort(names)

local totalPassed = 0
local totalFailed = 0
local allFailures = {}

for _, name in names do
	local t = harness.newContext(name)
	specs[name](t)
	totalPassed += t.passed
	totalFailed += t.failed
	for _, failure in t.failures do
		table.insert(allFailures, failure)
	end
	print(string.format("%-14s %d passed, %d failed", name, t.passed, t.failed))
end

print(("-"):rep(40))
print(`total: {totalPassed} passed, {totalFailed} failed`)

if totalFailed > 0 then
	for _, failure in allFailures do
		print(`  FAIL {failure}`)
	end
	process.exit(1)
end
