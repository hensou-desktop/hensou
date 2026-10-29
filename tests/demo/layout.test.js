const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const policy = {};
vm.runInNewContext(fs.readFileSync("apps/demo/qml/LayoutPlan.js", "utf8"), policy);
for (const [width, height, structure] of [[219, 640, "overflow"], [220, 640, "stack"], [221, 640, "stack"], [1000, 155, "overflow"], [1000, 156, "split"], [1000, 157, "split"], [599, 180, "stack"], [600, 180, "split"], [601, 180, "split"], [1000, 299, "split"], [1000, 300, "stack"], [1000, 301, "stack"]]) {
    const plan = policy.plan(width, height);
    assert.equal(plan.structure, structure);
    assert.deepEqual(Array.from(plan.inline).concat(Array.from(plan.overflow)).sort(), ["checkbox", "field", "list"]);
}
assert.equal(policy.plan(220, 640, { increment: 150, menu: 150 }).incrementInline, false);
assert.equal(policy.plan(220, 640, { increment: 90, menu: 60 }).incrementInline, true);
console.log("layout fit boundaries and whole-group reachability: PASS");
