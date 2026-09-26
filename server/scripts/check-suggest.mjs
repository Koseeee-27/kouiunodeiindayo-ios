// 提案の決め方（src/suggest.ts）を、偽の Jev で確かめる。本番の Worker も Jev も呼ばない（#114）。
// 使い方：npm run check:suggest（wrangler deploy --dry-run で .check/ に組み立ててから、これを node で動かす）。
// 例ごとに Vision のラベルと Jev の答えを決めて /suggest を呼び、返りが期待と違えば終了コード 1 で止まる。

import assert from "node:assert/strict";

// Node の crypto.subtle には timingSafeEqual が無いので、比べるだけの偽物を入れる（Workers にはある）。
if (!crypto.subtle.timingSafeEqual) {
  crypto.subtle.timingSafeEqual = (a, b) => Buffer.from(a).equals(Buffer.from(b));
}

const { default: worker } = await import(new URL("../.check/index.js", import.meta.url));
const env = { SUGGEST_TOKEN: "check-token", AI_GATEWAY_API_KEY: "check-key" };

// 偽の Jev。answers は { genre: ["food", 0.97], category: [...], cuisine: [...] } の形。
let jev = () => new Response("{}", { status: 500 });
globalThis.fetch = async () => jev();
function jevAnswers({ genre, category = ["none", 0.9], cuisine = ["none", 0.9] }) {
  const answer = ([choice, p]) => ({ choice, probabilities: { [choice]: p } });
  return () =>
    Response.json({ answers: { genre: answer(genre), category: answer(category), cuisine: answer(cuisine) } });
}

async function callSuggest(labels) {
  const response = await worker.fetch(
    new Request("http://localhost/suggest", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.SUGGEST_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ labels: labels.map(([name, confidence]) => ({ name, confidence })) }),
    }),
    env,
  );
  return { status: response.status, body: await response.json() };
}

const cases = [
  {
    name: "ラーメン（spaghetti が弱く出ている）＋ food → ラーメンだけ。パスタは付かない",
    labels: [["food", 0.8], ["ramen", 0.62], ["spaghetti", 0.24]],
    jev: { genre: ["food", 0.97], category: ["noodles", 0.9], cuisine: ["chinese", 0.8] },
    expect: { genre: "food", genreConfidence: 0.97, tags: ["ramen", "noodles", "chinese"] },
  },
  {
    name: "ラーメンのラベル＋ Jev が drink → 料理のタグ・大分類・系統は付かない",
    labels: [["food", 0.5], ["ramen", 0.62]],
    jev: { genre: ["drink", 0.9], category: ["noodles", 0.9], cuisine: ["chinese", 0.8] },
    expect: { genre: "drink", genreConfidence: 0.9, tags: [] },
  },
  {
    name: "コーヒー＋ Jev が food → コーヒーは付かない",
    labels: [["drink", 0.6], ["coffee", 0.8]],
    jev: { genre: ["food", 0.8] },
    expect: { genre: "food", genreConfidence: 0.8, tags: [] },
  },
  {
    name: "コーヒー＋ Jev が drink → コーヒー",
    labels: [["drink", 0.6], ["coffee", 0.8]],
    jev: { genre: ["drink", 0.95], category: ["none", 0.9] },
    expect: { genre: "drink", genreConfidence: 0.95, tags: ["coffee"] },
  },
  {
    name: "唐揚げ弁当（fried_chicken 0.18）＋ food → 唐揚げ（0.15 以上）",
    labels: [["food", 0.6], ["fried_chicken", 0.18]],
    jev: { genre: ["food", 0.97] },
    expect: { genre: "food", genreConfidence: 0.97, tags: ["karaage", "fried"] },
  },
  {
    name: "料理名が 0.14 → 料理のタグは付かない",
    labels: [["food", 0.6], ["ramen", 0.14]],
    jev: { genre: ["food", 0.97] },
    expect: { genre: "food", genreConfidence: 0.97, tags: [] },
  },
  {
    name: "料理名が同じ強さ → DISH_TAGS の順で先（ラーメン）",
    labels: [["food", 0.6], ["spaghetti", 0.4], ["ramen", 0.4]],
    jev: { genre: ["food", 0.97] },
    expect: { genre: "food", genreConfidence: 0.97, tags: ["ramen", "noodles", "chinese"] },
  },
  {
    name: "デザートにケーキと唐揚げ → ケーキが強ければケーキだけ。大分類は付かない",
    labels: [["dessert", 0.7], ["cake", 0.5], ["fried_chicken", 0.3]],
    jev: { genre: ["dessert", 0.9], category: ["fried", 0.6] },
    expect: { genre: "dessert", genreConfidence: 0.9, tags: ["cake"] },
  },
  {
    name: "食べ物に弱いケーキ → ケーキは付かない（食い違い）",
    labels: [["food", 0.7], ["cake", 0.2]],
    jev: { genre: ["food", 0.97] },
    expect: { genre: "food", genreConfidence: 0.97, tags: [] },
  },
  {
    name: "食べ物系が弱い（tableware 0.9・food 0.21）＋ food 0.97 → genreConfidence は null",
    labels: [["tableware", 0.9], ["food", 0.21]],
    jev: { genre: ["food", 0.97] },
    expect: { genre: "food", genreConfidence: null, tags: [] },
  },
  {
    name: "食べ物系が 0.30 ちょうど → genreConfidence を返す",
    labels: [["beverage", 0.3], ["cup", 0.5]],
    jev: { genre: ["drink", 0.9] },
    expect: { genre: "drink", genreConfidence: 0.9, tags: [] },
  },
  {
    name: "食べ物系のラベルが無い（料理名だけ）→ genreConfidence は null",
    labels: [["ramen", 0.7]],
    jev: { genre: ["food", 0.97] },
    expect: { genre: "food", genreConfidence: null, tags: ["ramen", "noodles", "chinese"] },
  },
  {
    name: "ジャンルなし（other）＋ ramen → ラーメンは付く（絞らない）",
    labels: [["food", 0.2], ["ramen", 0.62]],
    jev: { genre: ["other", 0.9] },
    expect: { genre: null, genreConfidence: null, tags: ["ramen", "noodles", "chinese"] },
  },
];

let failed = 0;
for (const c of cases) {
  jev = jevAnswers(c.jev);
  const { status, body } = await callSuggest(c.labels);
  try {
    assert.equal(status, 200);
    assert.deepEqual(body, c.expect);
    console.log(`ok   ${c.name}`);
  } catch {
    failed += 1;
    console.log(`NG   ${c.name}\n     期待 ${JSON.stringify(c.expect)}\n     実際 ${status} ${JSON.stringify(body)}`);
  }
}

// 決まって 502 の見立て（回数の制限）の再現：偽の Jev が 6 回目から 429 を返すと、6 回目から 502 になる。
{
  let calls = 0;
  jev = () => (++calls >= 6 ? Response.json({ error: { message: "rate limited" } }, { status: 429 }) : jevAnswers({ genre: ["food", 0.97] })());
  const statuses = [];
  for (let i = 0; i < 7; i++) statuses.push((await callSuggest([["food", 0.8]])).status);
  const name = "偽の Jev が 6 回目から 429 → 6 回目から 502";
  try {
    assert.deepEqual(statuses, [200, 200, 200, 200, 200, 502, 502]);
    console.log(`ok   ${name}`);
  } catch {
    failed += 1;
    console.log(`NG   ${name}\n     実際 ${statuses.join(", ")}`);
  }
}

console.log(failed === 0 ? `\n全部通った（${cases.length + 1} 件）` : `\n${failed} 件が違う`);
process.exit(failed === 0 ? 0 : 1);
