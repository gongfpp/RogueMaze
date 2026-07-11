import { DeckMode } from "./src/deck.js";
import { RoadId } from "./src/road.js";

export const SCENARIOS = Object.freeze([
  Object.freeze({
    id: "flat_success",
    title: "三张直路抵达终点",
    board: { width: 4, height: 1 },
    start: { roadId: RoadId.STRAIGHT, position: { x: 0, y: 0 } },
    end: { x: 3, y: 0 },
    deck: { cards: [RoadId.STRAIGHT], options: { mode: DeckMode.FIXED_CYCLE } },
    placements: [
      { position: { x: 1, y: 0 } },
      { position: { x: 2, y: 0 } },
      { position: { x: 3, y: 0 } },
    ],
    expected: { outcome: "WIN", turn: 3 },
  }),
  Object.freeze({
    id: "climb_success",
    title: "用两张坡道爬到上一层",
    board: { width: 3, height: 2 },
    start: { roadId: RoadId.STRAIGHT, position: { x: 0, y: 1 } },
    end: { x: 2, y: 0 },
    deck: {
      cards: [RoadId.UP_RAMP, RoadId.UP_RAMP, RoadId.STRAIGHT],
      options: { mode: DeckMode.FIXED_CYCLE },
    },
    placements: [
      { position: { x: 1, y: 1 } },
      { position: { x: 1, y: 0 }, quarterTurns: 2 },
      { position: { x: 2, y: 0 } },
    ],
    expected: { outcome: "WIN", turn: 3 },
  }),
  Object.freeze({
    id: "broken_failure",
    title: "竖直道路挡住水平出口",
    board: { width: 3, height: 2 },
    start: { roadId: RoadId.STRAIGHT, position: { x: 0, y: 0 } },
    end: { x: 2, y: 0 },
    deck: { cards: [RoadId.STRAIGHT], options: { mode: DeckMode.FIXED_CYCLE } },
    placements: [{ position: { x: 1, y: 0 }, quarterTurns: 1 }],
    expected: { outcome: "PLACEMENT_FAILED", reason: "PORT_MISMATCH", turn: 1 },
  }),
]);
