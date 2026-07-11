import assert from "node:assert/strict";
import test from "node:test";

import { SCENARIOS } from "../scenarios.js";
import { simulateScenario } from "../src/simulator.js";

for (const scenario of SCENARIOS) {
  test(`scenario: ${scenario.id}`, () => {
    const result = simulateScenario(scenario);
    assert.equal(result.outcome, scenario.expected.outcome);
    assert.equal(result.turn, scenario.expected.turn);
    if (scenario.expected.reason) {
      assert.equal(result.reason, scenario.expected.reason);
    }
  });
}
