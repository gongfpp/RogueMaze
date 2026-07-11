import assert from "node:assert/strict";
import test from "node:test";

import { DeckCycle, DeckMode } from "../src/deck.js";

function drawAndDiscard(deck, count) {
  const result = [];
  for (let index = 0; index < count; index += 1) {
    const card = deck.draw();
    result.push(card);
    deck.discard(card);
  }
  return result;
}

test("fixed cycle repeats the authored order forever", () => {
  const deck = new DeckCycle(["A", "B", "C"], { mode: DeckMode.FIXED_CYCLE });
  assert.deepEqual(drawAndDiscard(deck, 7), ["A", "B", "C", "A", "B", "C", "A"]);
});

test("shuffle discard is replayable with the same seed", () => {
  const options = { mode: DeckMode.SHUFFLE_DISCARD, seed: 20260712 };
  const first = drawAndDiscard(new DeckCycle(["A", "B", "C", "D"], options), 12);
  const second = drawAndDiscard(new DeckCycle(["A", "B", "C", "D"], options), 12);
  assert.deepEqual(first, second);
});

test("shuffle discard changes later cycles when the seed changes", () => {
  const first = drawAndDiscard(
    new DeckCycle(["A", "B", "C", "D"], { mode: DeckMode.SHUFFLE_DISCARD, seed: 1 }),
    12,
  );
  const second = drawAndDiscard(
    new DeckCycle(["A", "B", "C", "D"], { mode: DeckMode.SHUFFLE_DISCARD, seed: 2 }),
    12,
  );
  assert.notDeepEqual(first, second);
});
