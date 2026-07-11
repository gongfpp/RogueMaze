export const Direction = Object.freeze({
  LEFT: "left",
  UP: "up",
  RIGHT: "right",
  DOWN: "down",
});

export const DIRECTION_ORDER = Object.freeze([
  Direction.LEFT,
  Direction.UP,
  Direction.RIGHT,
  Direction.DOWN,
]);

export const DIRECTION_VECTOR = Object.freeze({
  [Direction.LEFT]: Object.freeze({ x: -1, y: 0 }),
  [Direction.UP]: Object.freeze({ x: 0, y: -1 }),
  [Direction.RIGHT]: Object.freeze({ x: 1, y: 0 }),
  [Direction.DOWN]: Object.freeze({ x: 0, y: 1 }),
});

export const OPPOSITE_DIRECTION = Object.freeze({
  [Direction.LEFT]: Direction.RIGHT,
  [Direction.UP]: Direction.DOWN,
  [Direction.RIGHT]: Direction.LEFT,
  [Direction.DOWN]: Direction.UP,
});

export const RoadId = Object.freeze({
  STRAIGHT: "straight",
  UP_RAMP: "up_ramp",
  DOWN_RAMP: "down_ramp",
  TURN: "turn",
  BRIDGE: "bridge",
});

function road(id, ports, keywords = []) {
  return Object.freeze({
    id,
    ports: Object.freeze([...ports]),
    keywords: Object.freeze([...keywords]),
  });
}

export const ROAD_DEFINITIONS = Object.freeze({
  [RoadId.STRAIGHT]: road(RoadId.STRAIGHT, [Direction.LEFT, Direction.RIGHT]),
  [RoadId.UP_RAMP]: road(RoadId.UP_RAMP, [Direction.LEFT, Direction.UP]),
  [RoadId.DOWN_RAMP]: road(RoadId.DOWN_RAMP, [Direction.LEFT, Direction.DOWN]),
  [RoadId.TURN]: road(RoadId.TURN, [Direction.UP, Direction.RIGHT]),
  [RoadId.BRIDGE]: road(RoadId.BRIDGE, [Direction.LEFT, Direction.RIGHT], ["bridge"]),
});

export function normalizeQuarterTurns(quarterTurns) {
  if (!Number.isInteger(quarterTurns)) {
    throw new TypeError("quarterTurns must be an integer");
  }
  return ((quarterTurns % 4) + 4) % 4;
}

export function rotateDirection(direction, quarterTurns) {
  const startIndex = DIRECTION_ORDER.indexOf(direction);
  if (startIndex === -1) {
    throw new RangeError(`Unknown direction: ${direction}`);
  }
  const turns = normalizeQuarterTurns(quarterTurns);
  return DIRECTION_ORDER[(startIndex + turns) % DIRECTION_ORDER.length];
}

export function rotatedPorts(roadDefinition, quarterTurns = 0) {
  if (!roadDefinition?.ports) {
    throw new TypeError("roadDefinition must contain ports");
  }
  return new Set(roadDefinition.ports.map((direction) => rotateDirection(direction, quarterTurns)));
}
