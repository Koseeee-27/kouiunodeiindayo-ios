// Jev（Vercel AI Gateway 経由の typesafe-ai/jev）とのやり取り。質問の文面と、答えの読み取りだけを置く。
// 呼び方と入出力の形は Vercel のドキュメント（https://vercel.com/docs/ai-gateway/modalities/evaluation）。経路の理由は ADR 0007。

import { CATEGORIES, CUISINES, type CategoryKey, type CuisineKey } from "./tags";

const ENDPOINT = "https://ai-gateway.vercel.sh/v1/evaluate";
const MODEL = "typesafe-ai/jev";
// アプリ側の時間切れ（1.5 秒）より先に切って 502 にする。手元で測った所要時間は 0.3〜0.9 秒（wrangler dev、2026-09-26。docs/plans/suggestion-worker.plan.md「決めたこと」）。
// 起動直後の最初の 1 回だけ 1.2 秒を超えることがあるが、その場合はアプリが次に仕分けを開いたときに問い合わせ直す（docs/architecture.md）。
const SUGGEST_TIMEOUT_MS = 1200;

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

type JevRequest = {
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
// error.message は上流が送った state（ラベル）を含めて返す可能性があるので、先頭 80 文字で切ってログに乗る量を抑える。
// withDetail が false なら状態コードだけにする（/search は state に検索の言葉が入るので、上流の文を 1 文字もログに乗せない）。
async function upstreamError(response: Response, withDetail: boolean): Promise<Error> {
  let detail = "";
  if (!withDetail) {
    return new Error(`jev http ${response.status}`);
  }
  try {
    const body = (await response.json()) as { error?: { message?: unknown } };
    if (typeof body?.error?.message === "string") {
      detail = `: ${body.error.message.slice(0, 80)}`;
    }
  } catch {
    // 本文が JSON でなければ状態コードだけにする。
  }
  return new Error(`jev http ${response.status}${detail}`);
}

// 503 のときだけ、締め切りまでに RETRY_MIN_MS 以上残っていれば 1 回だけ送り直す。
// 503 は Vercel 側の一時的な失敗で 0.3 秒で返り、手元の実測で 3 割・本番で 7 回中 1 回あった。
// 503 以外の 4xx/5xx・時間切れ・ネットワークエラーは再試行しない（送り直しても同じ結果か、時間を食うだけ）。
const RETRY_MIN_MS = 300;

async function postToJev(apiKey: string, body: string, timeoutMs: number): Promise<Response> {
  return fetch(ENDPOINT, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body,
    signal: AbortSignal.timeout(timeoutMs),
  });
}

// /suggest の問い合わせ。質問は buildQuestions() の 3 つ、締め切りは SUGGEST_TIMEOUT_MS。
export async function askJev(apiKey: string, state: string): Promise<JevResult> {
  const answers = await askJevQuestions(apiKey, state, buildQuestions(), SUGGEST_TIMEOUT_MS);
  // askJevQuestions が選択肢のキーであることを確かめているので、ここでの型の絞り込みは安全。
  return {
    genre: answers.genre as JevResult["genre"],
    category: answers.category as JevResult["category"],
    cuisine: answers.cuisine as JevResult["cuisine"],
  };
}

// 質問ごとの答え（選んだキーと、その確率）を、渡した questions のキーで返す。/suggest と /search（search.ts）で共通。
// 答えの形が想定と違うときは throw する。呼ぶ側で 502 にする（200 の提案なしにしない。suggestion-api.md「エラー」）。
// 全体の締め切りは timeoutMs に固定し、1 回目も 2 回目も残り時間で AbortSignal.timeout を作る。
// upstreamDetail が false なら、200 以外のときの Error に上流の error.message を入れない（upstreamError）。
export async function askJevQuestions(
  apiKey: string,
  state: string,
  questions: Record<string, JevQuestion>,
  timeoutMs: number,
  upstreamDetail = true,
): Promise<Record<string, JevAnswer>> {
  const request: JevRequest = { model: MODEL, state, questions };
  const payload = JSON.stringify(request);
  const deadline = Date.now() + timeoutMs;

  let response = await postToJev(apiKey, payload, timeoutMs);
  if (response.status === 503) {
    const remaining = deadline - Date.now();
    if (remaining >= RETRY_MIN_MS) {
      response = await postToJev(apiKey, payload, remaining);
    }
  }
  if (!response.ok) {
    throw await upstreamError(response, upstreamDetail);
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
  return Object.fromEntries(Object.keys(questions).map((id) => [id, read(id)]));
}
