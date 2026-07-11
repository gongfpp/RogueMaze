import { SCENARIOS } from "./scenarios.js";
import { simulateScenario } from "./src/simulator.js";

for (const scenario of SCENARIOS) {
  const result = simulateScenario(scenario);
  const reason = result.reason ? `，原因：${result.reason}` : "";
  console.log(`${scenario.id}｜${scenario.title}：${result.outcome}，第 ${result.turn} 回合${reason}`);
}
