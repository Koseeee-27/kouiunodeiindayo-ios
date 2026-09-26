// POST /suggest の本体。受け渡しの形は docs/suggestion-api.md、決め方は docs/plans/suggestion-worker.plan.md。

import { askJev, buildState, type Genre } from "./jev";
import {
  DISH_LABEL_MIN,
  DISH_TAGS,
  GENRE_MIN,
  LABEL_MIN,
  STRONG_MIN,
  TAG_MIN,
} from "./tags";

export interface Label {
  name: string;
  confidence: number;
}

export interface Suggestion {
  genre: Genre | null;
  // genre を返すときの Jev の probabilities[genre]。小数第 2 位に丸める。genre が null なら null。
  // アプリはおまかせで任せるかの判定に使う（境目はアプリ側。suggestion-api.md「確信度の扱い」）
  genreConfidence: number | null;
  tags: string[];
}

// 構造が違う本文のときに投げる。index.ts で 400 にする。
export class BadRequestError extends Error {}

const MAX_LABELS = 20;
const LABEL_NAME = /^[a-z0-9_]{1,64}$/;

// 本文を検証してラベルを取り出す。形に合わない名前のラベルは 400 にせず捨てる（suggestion-api.md「ラベルの名前の扱い」）。
export function parseLabels(body: unknown): Label[] {
  if (typeof body !== "object" || body === null) {
    throw new BadRequestError("body must be an object");
  }
  const labels = (body as Record<string, unknown>).labels;
  if (!Array.isArray(labels) || labels.length < 1 || labels.length > MAX_LABELS) {
    throw new BadRequestError(`labels must have 1 to ${MAX_LABELS} items`);
  }
  const valid: Label[] = [];
  for (const item of labels) {
    if (typeof item !== "object" || item === null) {
      throw new BadRequestError("each label must be an object");
    }
    const { name, confidence } = item as Record<string, unknown>;
    if (typeof name !== "string") {
      throw new BadRequestError("label name must be a string");
    }
    if (typeof confidence !== "number" || !(confidence >= 0 && confidence <= 1)) {
      throw new BadRequestError("label confidence must be a number from 0 to 1");
    }
    if (LABEL_NAME.test(name)) {
      valid.push({ name, confidence });
    }
  }
  return valid;
}

// apiKey は Vercel AI Gateway の API キー。しきい値の比較先 confidence は、Jev の probabilities[choice]（ADR 0007）。
export async function suggest(apiKey: string, allLabels: Label[]): Promise<Suggestion> {
  const labels = allLabels.filter((label) => label.confidence >= LABEL_MIN);
  if (labels.length === 0) {
    return { genre: null, genreConfidence: null, tags: [] };
  }

  const strong = labels.filter((label) => label.confidence >= STRONG_MIN).map((label) => label.name);
  const weak = labels.filter((label) => label.confidence < STRONG_MIN).map((label) => label.name);
  const answers = await askJev(apiKey, buildState(strong, weak));

  const genre =
    answers.genre.choice === "other" || answers.genre.confidence < GENRE_MIN
      ? null
      : answers.genre.choice;
  const genreConfidence = genre === null ? null : Math.round(answers.genre.confidence * 100) / 100;

  const dishLabels = new Set(
    labels.filter((label) => label.confidence >= DISH_LABEL_MIN).map((label) => label.name),
  );
  const dishes = DISH_TAGS.filter((dish) => dish.labels.some((name) => dishLabels.has(name)));

  const categories: string[] = [];
  const cuisines: string[] = [];
  for (const dish of dishes) {
    if (dish.category) categories.push(dish.category);
    if (dish.cuisine) cuisines.push(dish.cuisine);
  }
  if (answers.category.choice !== "none" && answers.category.confidence >= TAG_MIN) {
    categories.push(answers.category.choice);
  }
  if (answers.cuisine.choice !== "none" && answers.cuisine.confidence >= TAG_MIN) {
    cuisines.push(answers.cuisine.choice);
  }

  // Set は入れた順を保つので、並びは 料理 → 大分類 → 系統 のまま重複だけ消える。
  const tags = [...new Set([...dishes.map((dish) => dish.key), ...categories, ...cuisines])];
  return { genre, genreConfidence, tags };
}
