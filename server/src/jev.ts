// Jev（Vercel AI Gateway 経由の typesafe-ai/jev）とのやり取り。質問の文面と、答えの読み取りだけを置く。
// 呼び方と入出力の形は Vercel のドキュメント（https://vercel.com/docs/ai-gateway/modalities/evaluation）。経路の理由は ADR 0007。

import { CATEGORIES, CUISINES, type CategoryKey, type CuisineKey } from "./tags";

const ENDPOINT = "https://ai-gateway.vercel.sh/v1/evaluate";
const MODEL = "typesafe-ai/jev";
// アプリ側の時間切れ（1.5 秒）より先に切って 502 にする。手元で測った所要時間は 0.3〜0.9 秒（wrangler dev、2026-09-26。docs/plans/suggestion-worker.plan.md「決めたこと」）。
// 起動直後の最初の 1 回だけ 1.2 秒を超えることがあるが、その場合はアプリが次に仕分けを開いたときに問い合わせ直す（docs/architecture.md）。
const TIMEOUT_MS = 1200;

export type Genre = "food" | "drink" | "dessert";
const GENRE_CHOICES = {
  food: "a meal or dish",
  drink: "a beverage such as coffee, tea, beer, juice",
  dessert: "a sweet such as cake, ice cream, pastry",
  other: "not food or drink, or cannot tell",
};

const NONE_CHOICE = "none";

export type JevQuestion = {
  type: "choice";
  instructions: string;
  criteria: Record<string, string>;
};

export type JevRequest = {
  model: string;
  state: string;
  questions: Record<string, JevQuestion>;
};

// confidence は、Vercel の答えには無いので、選ばれたキーの probabilities の値を入れる（ADR 0007）。
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

// HTTP が 200 以外のときの Error。状態コードと Vercel の error.message だけを入れる（送った本文＝ラベルは入れない）。
async function upstreamError(response: Response): Promise<Error> {
  let detail = "";
  try {
    const body = (await response.json()) as { error?: { message?: unknown } };
    if (typeof body?.error?.message === "string") {
      detail = `: ${body.error.message}`;
    }
  } catch {
    // 本文が JSON でなければ状態コードだけにする。
  }
  return new Error(`jev http ${response.status}${detail}`);
}

// 答えの形が想定と違うときは throw する。呼ぶ側で 502 にする（200 の提案なしにしない。suggestion-api.md「エラー」）。
export async function askJev(apiKey: string, state: string): Promise<JevResult> {
  const questions = buildQuestions();
  const request: JevRequest = { model: MODEL, state, questions };
  const response = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(request),
    signal: AbortSignal.timeout(TIMEOUT_MS),
  });
  if (!response.ok) {
    throw await upstreamError(response);
  }
  const body = (await response.json()) as { answers?: unknown };
  const answers = body.answers;
  if (typeof answers !== "object" || answers === null) {
    throw new Error("jev response has no answers");
  }
  const read = (id: string): JevAnswer => {
    const answer = (answers as Record<string, unknown>)[id];
    if (typeof answer !== "object" || answer === null) {
      throw new Error(`jev answer missing: ${id}`);
    }
    const { choice, probabilities } = answer as Record<string, unknown>;
    if (typeof choice !== "string" || !Object.hasOwn(questions[id].criteria, choice)) {
      throw new Error(`jev choice out of options: ${id}`);
    }
    if (typeof probabilities !== "object" || probabilities === null) {
      throw new Error(`jev probabilities missing: ${id}`);
    }
    const confidence = (probabilities as Record<string, unknown>)[choice];
    if (typeof confidence !== "number") {
      throw new Error(`jev probability missing: ${id}`);
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
