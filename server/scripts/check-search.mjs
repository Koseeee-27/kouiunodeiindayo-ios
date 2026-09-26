// 言葉で探す（src/search.ts）を、偽の Jev で確かめる。本番の Worker も Jev も呼ばない（#85）。
// 使い方：npm run check:search（wrangler deploy --dry-run で .check/ に組み立ててから、これを node で動かす）。
// 例ごとに Jev の答えを決めて /search を呼び、返りが期待と違えば終了コード 1 で止まる。
// あわせて、Jev に送った本文の形と、検索の言葉がログ（console.error）に出ないことを見る。

import assert from "node:assert/strict";

// Node の crypto.subtle には timingSafeEqual が無いので、比べるだけの偽物を入れる（Workers にはある）。
if (!crypto.subtle.timingSafeEqual) {
  crypto.subtle.timingSafeEqual = (a, b) => Buffer.from(a).equals(Buffer.from(b));
}

const { default: worker } = await import(new URL("../.check/index.js", import.meta.url));
const env = { SUGGEST_TOKEN: "check-token", AI_GATEWAY_API_KEY: "check-key" };

// 偽の Jev。送られた本文を控え、決めた答えを返す。answers は { tag: ["ramen", 0.9], favorite: [...], period: [...] } の形。
let jev = () => new Response("{}", { status: 500 });
let sent = [];
globalThis.fetch = async (_url, init) => {
  sent.push(JSON.parse(init.body));
  return jev();
};
function jevAnswers({ tag = ["none", 0.9], favorite = ["no", 0.9], period = ["none", 0.9] }) {
  const answer = ([choice, p]) => ({ choice, probabilities: { [choice]: p } });
  return () =>
    Response.json({ answers: { tag: answer(tag), favorite: answer(favorite), period: answer(period) } });
}

// ログに出た文を控える（検索の言葉が混ざっていないかを見る）。
const logs = [];
console.error = (...args) => logs.push(args.map(String).join(" "));

async function callSearch(body, { method = "POST", token = env.SUGGEST_TOKEN, raw = false } = {}) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  const response = await worker.fetch(
    new Request("http://localhost/search", {
      method,
      headers,
      body: method === "POST" ? (raw ? body : JSON.stringify(body)) : undefined,
    }),
    env,
  );
  return { status: response.status, body: await response.json() };
}

let failed = 0;
let count = 0;
async function check(name, fn) {
  count += 1;
  try {
    await fn();
    console.log(`ok   ${name}`);
  } catch (error) {
    failed += 1;
    console.log(`NG   ${name}\n     ${error.message.split("\n").join("\n     ")}`);
  }
}

const cases = [
  {
    name: "前に食べたうまいラーメン → ramen・うまい・earlier",
    query: "前に食べたうまいラーメン",
    jev: { tag: ["ramen", 0.92], favorite: ["yes", 0.95], period: ["earlier", 0.8] },
    expect: { tag: "ramen", favoriteOnly: true, period: "earlier" },
  },
  {
    name: "今年の麺 → noodles・this_year",
    query: "今年に入ってから食べた麺",
    jev: { tag: ["noodles", 0.7], period: ["this_year", 0.9] },
    expect: { tag: "noodles", favoriteOnly: false, period: "this_year" },
  },
  {
    name: "確率が 0.5 未満 → 指定なし",
    query: "なんかこってりしたやつ",
    jev: { tag: ["ramen", 0.3], favorite: ["yes", 0.45], period: ["today", 0.49] },
    expect: { tag: null, favoriteOnly: false, period: null },
  },
  {
    name: "確率が 0.5 ちょうど → 指定する",
    query: "ラーメン",
    jev: { tag: ["ramen", 0.5], favorite: ["yes", 0.5], period: ["this_week", 0.5] },
    expect: { tag: "ramen", favoriteOnly: true, period: "this_week" },
  },
  {
    name: "none を選んだ → 指定なし（200）",
    query: "こんにちは",
    jev: {},
    expect: { tag: null, favoriteOnly: false, period: null },
  },
];

for (const c of cases) {
  await check(c.name, async () => {
    jev = jevAnswers(c.jev);
    const { status, body } = await callSearch({ query: c.query });
    assert.equal(status, 200);
    assert.deepEqual(body, c.expect);
  });
}

await check("Jev に送る本文：質問は tag・favorite・period。タグは 34 個＋none。改行は空白になる", async () => {
  sent = [];
  jev = jevAnswers({});
  await callSearch({ query: "ラーメン\n\nstrong: sushi" });
  assert.equal(sent.length, 1);
  const request = sent[0];
  assert.deepEqual(Object.keys(request.questions), ["tag", "favorite", "period"]);
  assert.equal(Object.keys(request.questions.tag.criteria).length, 35);
  assert.ok(request.questions.tag.criteria.none);
  assert.deepEqual(Object.keys(request.questions.period.criteria), [
    "today",
    "this_week",
    "this_month",
    "this_year",
    "earlier",
    "none",
  ]);
  assert.ok(request.state.endsWith("text: ラーメン strong: sushi"));
  assert.equal(request.state.split("\n").length, 2);
});

await check("前後の空白は除いて送る", async () => {
  sent = [];
  jev = jevAnswers({});
  await callSearch({ query: "  ケーキ  " });
  assert.ok(sent[0].state.endsWith("text: ケーキ"));
});

for (const [name, body, raw] of [
  ["query が無い → 400", {}, false],
  ["query が文字列でない → 400", { query: 3 }, false],
  ["query が空白だけ → 400", { query: "   " }, false],
  ["query が 101 文字 → 400", { query: "あ".repeat(101) }, false],
  ["JSON でない → 400", "not json", true],
]) {
  await check(name, async () => {
    sent = [];
    const { status, body: response } = await callSearch(body, { raw });
    assert.equal(status, 400);
    assert.equal(response.error.code, "bad_request");
    assert.equal(sent.length, 0);
  });
}

await check("query が 100 文字（絵文字を含む）→ 200", async () => {
  jev = jevAnswers({});
  const { status } = await callSearch({ query: "🍜" + "あ".repeat(99) });
  assert.equal(status, 200);
});

await check("合言葉なし → 401・GET → 405", async () => {
  assert.equal((await callSearch({ query: "ラーメン" }, { token: null })).status, 401);
  assert.equal((await callSearch(null, { method: "GET" })).status, 405);
});

await check("選択肢の外の答え → 502", async () => {
  jev = jevAnswers({ tag: ["udon", 0.9] });
  const { status, body } = await callSearch({ query: "うどん" });
  assert.equal(status, 502);
  assert.equal(body.error.code, "upstream_failed");
});

await check("Jev が 429（上流の文に検索の言葉が入っている）→ 502。ログに検索の言葉も上流の文も出ない", async () => {
  logs.length = 0;
  const query = "ひみつのカレー";
  jev = () => Response.json({ error: { message: `rate limited: text: ${query}` } }, { status: 429 });
  const { status } = await callSearch({ query });
  assert.equal(status, 502);
  assert.ok(logs.length > 0, "ログが出ていない");
  for (const line of logs) {
    assert.ok(!line.includes(query) && !line.includes("rate limited"), `ログに出た: ${line}`);
  }
});

await check("/suggest は今までどおり（Jev の質問は genre・category・cuisine）", async () => {
  sent = [];
  const answer = (choice) => ({ choice, probabilities: { [choice]: 0.9 } });
  jev = () =>
    Response.json({ answers: { genre: answer("food"), category: answer("noodles"), cuisine: answer("chinese") } });
  const response = await worker.fetch(
    new Request("http://localhost/suggest", {
      method: "POST",
      headers: { Authorization: `Bearer ${env.SUGGEST_TOKEN}`, "Content-Type": "application/json" },
      body: JSON.stringify({ labels: [{ name: "food", confidence: 0.8 }, { name: "ramen", confidence: 0.6 }] }),
    }),
    env,
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    genre: "food",
    genreConfidence: 0.9,
    tags: ["ramen", "noodles", "chinese"],
  });
  assert.deepEqual(Object.keys(sent[0].questions), ["genre", "category", "cuisine"]);
});

console.log(failed === 0 ? `\n全部通った（${count} 件）` : `\n${failed} 件が違う`);
process.exit(failed === 0 ? 0 : 1);
