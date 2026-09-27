// POST /search の本体（機能28）。受け渡しの形は docs/suggestion-api.md、決め方は docs/plans/word-search.plan.md の M2。
// 検索の言葉はログに出さない（ADR 0006）。Jev の失敗も、上流の文を入れずに状態コードだけにする（jev.ts の upstreamDetail）。

import { askJevQuestions, type JevQuestion } from "./jev";
import { BadRequestError } from "./suggest";
import { SEARCH_TAGS } from "./tags";

export type SearchPeriod = "today" | "this_week" | "this_month" | "this_year" | "earlier";

export interface SearchResult {
  tag: string | null;
  favoriteOnly: boolean;
  period: SearchPeriod | null;
}

// 検索の言葉の長さ（前後の空白を除いた文字数）。suggestion-api.md「送る」。
const MAX_QUERY = 100;
// Jev の probabilities[choice] がこれ未満なら指定なし。/suggest の GENRE_MIN と同じ考え（選択肢の「残り全部より高い」）。
// タグは 35 択なので割れやすい。本番で指定なしが多すぎたら 0.4 に下げるかを決める（計画のリスク）。
export const SEARCH_MIN = 0.5;
// アプリの時間切れ（3 秒）より先に切って 502 にする。
const SEARCH_TIMEOUT_MS = 2500;

const NONE_CHOICE = "none";

const PERIOD_CHOICES: Record<SearchPeriod | typeof NONE_CHOICE, string> = {
  today: "today (今日)",
  this_week: "this week (今週)",
  this_month: "this month (今月)",
  this_year: "since January 1 this year (今年)",
  earlier: "before this month, e.g. 前に, 昔, 以前",
  none: "no time is mentioned",
};

// 本文を検証して、前後の空白を除いた検索の言葉を返す。違えば BadRequestError（index.ts で 400）。
export function parseQuery(body: unknown): string {
  if (typeof body !== "object" || body === null) {
    throw new BadRequestError("body must be an object");
  }
  const query = (body as Record<string, unknown>).query;
  if (typeof query !== "string") {
    throw new BadRequestError("query must be a string");
  }
  const trimmed = query.trim();
  // 文字数はコードポイントで数える（絵文字 1 つを 2 文字に数えない）。
  const length = [...trimmed].length;
  if (length < 1 || length > MAX_QUERY) {
    throw new BadRequestError(`query must have 1 to ${MAX_QUERY} characters`);
  }
  return trimmed;
}

// 改行は空白にする（質問の形を崩されないように）。
export function buildSearchState(query: string): string {
  return [
    "A user of a Japanese food diary app typed this search text. Pick conditions to filter their records.",
    `text: ${query.replace(/[\r\n]+/g, " ")}`,
  ].join("\n");
}

export function buildSearchQuestions(): Record<string, JevQuestion> {
  return {
    tag: {
      type: "choice",
      instructions: "Which food or drink does the text ask for? Pick the most specific one.",
      criteria: { ...SEARCH_TAGS, [NONE_CHOICE]: "no food or drink is mentioned" },
    },
    favorite: {
      type: "choice",
      instructions: "Does the text ask only for records the user found delicious or marked as favorite?",
      criteria: {
        yes: "only delicious or favorite ones (うまい, おいしい, お気に入り)",
        no: "not limited to favorites",
      },
    },
    period: {
      type: "choice",
      instructions: "Which time does the text ask for?",
      criteria: PERIOD_CHOICES,
    },
  };
}

export async function search(apiKey: string, query: string): Promise<SearchResult> {
  const answers = await askJevQuestions(
    apiKey,
    buildSearchState(query),
    buildSearchQuestions(),
    SEARCH_TIMEOUT_MS,
    false,
  );
  const picked = (id: string): string | null => {
    const answer = answers[id];
    return answer.choice === NONE_CHOICE || answer.confidence < SEARCH_MIN ? null : answer.choice;
  };
  // askJevQuestions が選択肢のキーであることを確かめているので、period の型の絞り込みは安全。
  return {
    tag: picked("tag"),
    favoriteOnly: picked("favorite") === "yes",
    period: picked("period") as SearchPeriod | null,
  };
}
