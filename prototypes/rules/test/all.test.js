// Run all rule tests in one process. This also works in restricted environments
// that do not allow Node's default multi-process test discovery.
import "./board.test.js";
import "./deck.test.js";
import "./road.test.js";
import "./scenarios.test.js";
