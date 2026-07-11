export const DeckMode = Object.freeze({
  FIXED_CYCLE: "fixed_cycle",
  SHUFFLE_DISCARD: "shuffle_discard",
});

function createRandom(seed) {
  if (!Number.isInteger(seed)) {
    throw new TypeError("seed must be an integer");
  }
  let state = seed >>> 0;
  return () => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function shuffle(items, random) {
  const result = [...items];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(random() * (index + 1));
    [result[index], result[swapIndex]] = [result[swapIndex], result[index]];
  }
  return result;
}

export class DeckCycle {
  constructor(cards, { mode = DeckMode.FIXED_CYCLE, seed = 1 } = {}) {
    if (!Array.isArray(cards) || cards.length === 0) {
      throw new RangeError("Deck must contain at least one card");
    }
    if (!Object.values(DeckMode).includes(mode)) {
      throw new RangeError(`Unknown deck mode: ${mode}`);
    }

    this.cards = [...cards];
    this.mode = mode;
    this.fixedIndex = 0;
    this.drawPile = [...cards];
    this.discardPile = [];
    this.random = createRandom(seed);
  }

  draw() {
    if (this.mode === DeckMode.FIXED_CYCLE) {
      const card = this.cards[this.fixedIndex % this.cards.length];
      this.fixedIndex += 1;
      return card;
    }

    if (this.drawPile.length === 0) {
      if (this.discardPile.length === 0) {
        throw new Error("Cannot draw: both draw and discard piles are empty");
      }
      this.drawPile = shuffle(this.discardPile, this.random);
      this.discardPile = [];
    }
    return this.drawPile.shift();
  }

  discard(card) {
    if (this.mode === DeckMode.SHUFFLE_DISCARD) {
      this.discardPile.push(card);
    }
  }
}
