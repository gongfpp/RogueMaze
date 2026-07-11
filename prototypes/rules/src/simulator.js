import { Board } from "./board.js";
import { DeckCycle } from "./deck.js";
import { ROAD_DEFINITIONS } from "./road.js";

export const SimulationResult = Object.freeze({
  WIN: "WIN",
  PLACEMENT_FAILED: "PLACEMENT_FAILED",
  END_NOT_REACHED: "END_NOT_REACHED",
});

export function simulateScenario(scenario) {
  const board = new Board(scenario.board.width, scenario.board.height);
  const startRoad = ROAD_DEFINITIONS[scenario.start.roadId];
  const startResult = board.place(
    startRoad,
    scenario.start.position,
    scenario.start.quarterTurns ?? 0,
    { allowIsolated: true },
  );
  if (!startResult.ok) {
    throw new Error(`Scenario has invalid start road: ${startResult.reason}`);
  }

  const deck = new DeckCycle(scenario.deck.cards, scenario.deck.options);
  const history = [];

  for (let turn = 0; turn < scenario.placements.length; turn += 1) {
    const placement = scenario.placements[turn];
    const cardId = deck.draw();
    const roadDefinition = ROAD_DEFINITIONS[cardId];
    if (!roadDefinition) {
      throw new Error(`Unknown road card: ${cardId}`);
    }

    const result = board.place(
      roadDefinition,
      placement.position,
      placement.quarterTurns ?? 0,
    );
    history.push({ turn: turn + 1, cardId, placement, result });
    deck.discard(cardId);

    if (!result.ok) {
      return {
        outcome: SimulationResult.PLACEMENT_FAILED,
        reason: result.reason,
        turn: turn + 1,
        history,
      };
    }
    if (board.areConnected(scenario.start.position, scenario.end)) {
      return {
        outcome: SimulationResult.WIN,
        reason: null,
        turn: turn + 1,
        history,
      };
    }
  }

  return {
    outcome: SimulationResult.END_NOT_REACHED,
    reason: SimulationResult.END_NOT_REACHED,
    turn: scenario.placements.length,
    history,
  };
}
