// Jev（Workers AI の typesafe/jev）とのやり取り。質問の文面と、答えの読み取りだけを置く。
// 入出力の形は Cloudflare のモデルページ（https://developers.cloudflare.com/ai/models/typesafe/jev/）。

import { CATEGORIES, CUISINES, type CategoryKey, type CuisineKey } from "./tags";

const MODEL = "typesafe/jev";

export type Genre = "food" | "drink" | "dessert";
const GENRE_CHOICES = {
  food: "a meal or dish",
  drink: "a beverage such as coffee, tea, beer, juice",
  dessert: "a sweet such as cake, ice cream, pastry",
  other: "not food or drink, or cannot tell",
};

const NONE_CHOICE = "none";

// type（interface ではなく）にしているのは、env.AI.run の inputs（Record<string, unknown>）にそのまま渡せるようにするため。
export type JevQuestion = {
  type: "choice";
  instructions: string;
  criteria: Record<string, string>;
};

export type JevRequest = {
  state: string;
  questions: Record<string, JevQuestion>;
};

export interface JevAnswer {
  choice: string;
  confidence: number;
}

export interface JevResult {
  genre: JevAnswer & { choice: Genre | "other" };
  category: JevAnswer & { choice: CategoryKey | typeof NONE_CHOICE };
  cuisine: JevAnswer & { choice: CuisineKey | typeof NONE_CHOICE };
}

export function buildState(strong: string[], weak: string[]): string {
  return [
    "Labels detected in a photo by an on-device image classifier (Apple Vision).",
    "The photo may or may not show food or drink.",
    "Strong labels are likely correct. Weak labels are only hints.",
    `strong: ${strong.length > 0 ? strong.join(", ") : "(none)"}`,
    `weak: ${weak.length > 0 ? weak.join(", ") : "(none)"}`,
  ].join("\n");
}

export function buildQuestions(): Record<string, JevQuestion> {
  return {
    genre: {
      type: "choice",
      instructions: "What is mainly shown in the photo, judging from the labels?",
      criteria: GENRE_CHOICES,
    },
    category: {
      type: "choice",
      instructions: "What kind of dish is shown, judging from the labels?",
      criteria: { ...CATEGORIES, [NONE_CHOICE]: "none of these, or not a dish" },
    },
    cuisine: {
      type: "choice",
      instructions: "Which cuisine is the dish from, judging from the labels?",
      criteria: { ...CUISINES, [NONE_CHOICE]: "none of these, or cannot tell" },
    },
  };
}

// 答えの形が想定と違うときは throw する。呼ぶ側で 502 にする（200 の提案なしにしない。suggestion-api.md「エラー」）。
export async function askJev(ai: Ai, state: string): Promise<JevResult> {
  const questions = buildQuestions();
  const request: JevRequest = { state, questions };
  // worker-configuration.d.ts の Ai 型に typesafe/jev は無いので、戻り値は Record<string, unknown> で受けて中身を確かめる。
  const response = await ai.run(MODEL, request);
  const answers = response.answers;
  if (typeof answers !== "object" || answers === null) {
    throw new Error("jev response has no answers");
  }
  const read = (id: string): JevAnswer => {
    const answer = (answers as Record<string, unknown>)[id];
    if (typeof answer !== "object" || answer === null) {
      throw new Error(`jev answer missing: ${id}`);
    }
    const { choice, confidence } = answer as Record<string, unknown>;
    if (typeof choice !== "string" || !Object.hasOwn(questions[id].criteria, choice)) {
      throw new Error(`jev choice out of options: ${id}`);
    }
    if (typeof confidence !== "number") {
      throw new Error(`jev confidence missing: ${id}`);
    }
    return { choice, confidence };
  };
  // read が選択肢のキーであることを確かめているので、ここでの型の絞り込みは安全。
  return {
    genre: read("genre") as JevResult["genre"],
    category: read("category") as JevResult["category"],
    cuisine: read("cuisine") as JevResult["cuisine"],
  };
}
