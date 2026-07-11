import assert from "node:assert/strict";
import test from "node:test";

import { Direction, ROAD_DEFINITIONS, RoadId, rotateDirection, rotatedPorts } from "../src/road.js";

test("direction rotates clockwise and returns after four turns", () => {
  assert.equal(rotateDirection(Direction.LEFT, 1), Direction.UP);
  assert.equal(rotateDirection(Direction.LEFT, 2), Direction.RIGHT);
  assert.equal(rotateDirection(Direction.LEFT, 4), Direction.LEFT);
  assert.equal(rotateDirection(Direction.LEFT, -1), Direction.DOWN);
});

test("straight road becomes vertical after one quarter turn", () => {
  const ports = rotatedPorts(ROAD_DEFINITIONS[RoadId.STRAIGHT], 1);
  assert.deepEqual([...ports].sort(), [Direction.DOWN, Direction.UP].sort());
});

test("road definitions cover the five prototype road types", () => {
  assert.deepEqual(Object.keys(ROAD_DEFINITIONS).sort(), Object.values(RoadId).sort());
});
