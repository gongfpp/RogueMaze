import {
  DIRECTION_ORDER,
  DIRECTION_VECTOR,
  OPPOSITE_DIRECTION,
  rotatedPorts,
} from "./road.js";

export const PlacementFailure = Object.freeze({
  OUT_OF_BOUNDS: "OUT_OF_BOUNDS",
  OCCUPIED: "OCCUPIED",
  PORT_MISMATCH: "PORT_MISMATCH",
  ISOLATED: "ISOLATED",
});

function positionKey(position) {
  return `${position.x},${position.y}`;
}

function add(position, vector) {
  return { x: position.x + vector.x, y: position.y + vector.y };
}

export class Board {
  constructor(width, height) {
    if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0) {
      throw new RangeError("Board width and height must be positive integers");
    }
    this.width = width;
    this.height = height;
    this.roads = new Map();
  }

  isInside(position) {
    return (
      Number.isInteger(position?.x) &&
      Number.isInteger(position?.y) &&
      position.x >= 0 &&
      position.y >= 0 &&
      position.x < this.width &&
      position.y < this.height
    );
  }

  roadAt(position) {
    return this.roads.get(positionKey(position));
  }

  validatePlacement(roadDefinition, position, quarterTurns = 0, options = {}) {
    if (!this.isInside(position)) {
      return { ok: false, reason: PlacementFailure.OUT_OF_BOUNDS };
    }
    if (this.roadAt(position)) {
      return { ok: false, reason: PlacementFailure.OCCUPIED };
    }

    const ports = rotatedPorts(roadDefinition, quarterTurns);
    let matchingConnections = 0;

    for (const direction of DIRECTION_ORDER) {
      const neighborPosition = add(position, DIRECTION_VECTOR[direction]);
      const neighbor = this.roadAt(neighborPosition);
      if (!neighbor) {
        continue;
      }

      const thisOpens = ports.has(direction);
      const neighborOpens = neighbor.ports.has(OPPOSITE_DIRECTION[direction]);
      if (thisOpens !== neighborOpens) {
        return {
          ok: false,
          reason: PlacementFailure.PORT_MISMATCH,
          direction,
          neighborPosition,
        };
      }
      if (thisOpens && neighborOpens) {
        matchingConnections += 1;
      }
    }

    if (!options.allowIsolated && matchingConnections === 0) {
      return { ok: false, reason: PlacementFailure.ISOLATED };
    }

    return { ok: true, matchingConnections };
  }

  place(roadDefinition, position, quarterTurns = 0, options = {}) {
    const validation = this.validatePlacement(roadDefinition, position, quarterTurns, options);
    if (!validation.ok) {
      return validation;
    }

    const placedRoad = Object.freeze({
      definition: roadDefinition,
      position: Object.freeze({ x: position.x, y: position.y }),
      quarterTurns,
      ports: rotatedPorts(roadDefinition, quarterTurns),
    });
    this.roads.set(positionKey(position), placedRoad);
    return { ok: true, road: placedRoad, matchingConnections: validation.matchingConnections };
  }

  areConnected(start, end) {
    if (!this.roadAt(start) || !this.roadAt(end)) {
      return false;
    }

    const targetKey = positionKey(end);
    const visited = new Set([positionKey(start)]);
    const queue = [start];

    while (queue.length > 0) {
      const currentPosition = queue.shift();
      const current = this.roadAt(currentPosition);
      if (positionKey(currentPosition) === targetKey) {
        return true;
      }

      for (const direction of current.ports) {
        const neighborPosition = add(currentPosition, DIRECTION_VECTOR[direction]);
        const neighbor = this.roadAt(neighborPosition);
        if (!neighbor || !neighbor.ports.has(OPPOSITE_DIRECTION[direction])) {
          continue;
        }
        const neighborKey = positionKey(neighborPosition);
        if (!visited.has(neighborKey)) {
          visited.add(neighborKey);
          queue.push(neighborPosition);
        }
      }
    }
    return false;
  }
}
