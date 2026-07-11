import assert from "node:assert/strict";
import test from "node:test";

import { Board, PlacementFailure } from "../src/board.js";
import { ROAD_DEFINITIONS, RoadId } from "../src/road.js";

const straight = ROAD_DEFINITIONS[RoadId.STRAIGHT];

function boardWithStart() {
  const board = new Board(4, 3);
  assert.equal(board.place(straight, { x: 0, y: 1 }, 0, { allowIsolated: true }).ok, true);
  return board;
}

test("matching left and right ports create a legal connection", () => {
  const board = boardWithStart();
  const result = board.place(straight, { x: 1, y: 1 });
  assert.equal(result.ok, true);
  assert.equal(result.matchingConnections, 1);
  assert.equal(board.areConnected({ x: 0, y: 1 }, { x: 1, y: 1 }), true);
});

test("placement outside the board is rejected", () => {
  const board = boardWithStart();
  assert.equal(board.place(straight, { x: 4, y: 1 }).reason, PlacementFailure.OUT_OF_BOUNDS);
});

test("placement on an occupied cell is rejected", () => {
  const board = boardWithStart();
  assert.equal(board.place(straight, { x: 0, y: 1 }).reason, PlacementFailure.OCCUPIED);
});

test("one-sided opening is rejected as a port mismatch", () => {
  const board = boardWithStart();
  const result = board.place(straight, { x: 1, y: 1 }, 1);
  assert.equal(result.reason, PlacementFailure.PORT_MISMATCH);
  assert.equal(result.direction, "left");
});

test("a road with no matching neighbor is rejected as isolated", () => {
  const board = boardWithStart();
  assert.equal(board.place(straight, { x: 3, y: 2 }).reason, PlacementFailure.ISOLATED);
});

test("connected search follows an upward route", () => {
  const board = boardWithStart();
  const ramp = ROAD_DEFINITIONS[RoadId.UP_RAMP];
  assert.equal(board.place(ramp, { x: 1, y: 1 }).ok, true);
  assert.equal(board.place(ramp, { x: 1, y: 0 }, 2).ok, true);
  assert.equal(board.place(straight, { x: 2, y: 0 }).ok, true);
  assert.equal(board.areConnected({ x: 0, y: 1 }, { x: 2, y: 0 }), true);
});
