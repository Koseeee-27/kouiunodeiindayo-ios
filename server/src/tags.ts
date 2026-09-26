// タグの対応表と、提案のしきい値。
// 料理の表は docs/data-model.md「タグの値」を写したもの。表を変えたら data-model.md も同じに直す。

export type CategoryKey =
  | "noodles"
  | "rice_dish"
  | "bread"
  | "meat"
  | "seafood"
  | "fried"
  | "egg"
  | "vegetables"
  | "soup";

export type CuisineKey = "japanese" | "western" | "chinese" | "korean" | "ethnic";

// 料理のタグの種類。ジャンル（jev.ts の Genre）と同じ値で、ジャンルと食い違うタグを除くのに使う。
export type DishKind = "food" | "drink" | "dessert";

export interface DishTag {
  key: string;
  kind: DishKind;
  labels: string[];
  // このタグだけ DISH_LABEL_MIN より高いしきい値にするとき（取り違えやすい料理）
  labelMin?: number;
  category: CategoryKey | null;
  cuisine: CuisineKey | null;
}

// パスタだけ、料理のタグのしきい値を DISH_LABEL_MIN（0.15）より上げる（#114）。
// Vision は、麺の料理（ラーメン・まぜそば・麻辣湯など）に spaghetti・pasta を 0.2〜0.5 で出しやすい。こうせいの写真では、
// 0.15〜0.30 でパスタが付いた 3 枚（spaghetti 0.23・0.21、pasta 0.27）が全部パスタでなかった。0.30 に戻しても、
// ほかの写真で失う正しいタグは無かった（作業用のメモ photos-0927 を直す前と後の Worker に流して確かめた）。
export const PASTA_LABEL_MIN = 0.3;

export const DISH_TAGS: DishTag[] = [
  { key: "ramen", kind: "food", labels: ["ramen"], category: "noodles", cuisine: "chinese" },
  {
    key: "pasta",
    kind: "food",
    labels: ["pasta", "spaghetti"],
    labelMin: PASTA_LABEL_MIN,
    category: "noodles",
    cuisine: "western",
  },
  { key: "sushi", kind: "food", labels: ["sushi"], category: "rice_dish", cuisine: "japanese" },
  { key: "curry", kind: "food", labels: ["curry"], category: "rice_dish", cuisine: null },
  { key: "gyoza", kind: "food", labels: ["gyoza", "dumpling"], category: null, cuisine: "chinese" },
  { key: "tempura", kind: "food", labels: ["tempura"], category: "fried", cuisine: "japanese" },
  { key: "karaage", kind: "food", labels: ["fried_chicken"], category: "fried", cuisine: null },
  { key: "pizza", kind: "food", labels: ["pizza"], category: null, cuisine: "western" },
  { key: "hamburger", kind: "food", labels: ["hamburger"], category: "bread", cuisine: "western" },
  { key: "steak", kind: "food", labels: ["steak"], category: "meat", cuisine: "western" },
  { key: "sandwich", kind: "food", labels: ["sandwich"], category: "bread", cuisine: "western" },
  { key: "coffee", kind: "drink", labels: ["coffee"], category: null, cuisine: null },
  { key: "tea", kind: "drink", labels: ["tea_drink"], category: null, cuisine: null },
  {
    key: "alcohol",
    kind: "drink",
    labels: ["beer", "wine", "red_wine", "white_wine", "sparkling_wine", "cocktail", "liquor"],
    category: null,
    cuisine: null,
  },
  { key: "juice", kind: "drink", labels: ["juice", "smoothie"], category: null, cuisine: null },
  { key: "bubble_tea", kind: "drink", labels: ["bubble_tea"], category: null, cuisine: null },
  {
    key: "cake",
    kind: "dessert",
    labels: ["cake", "cake_regular", "birthday_cake", "cheesecake", "cupcake"],
    category: null,
    cuisine: null,
  },
  { key: "ice_cream", kind: "dessert", labels: ["ice_cream"], category: null, cuisine: null },
  { key: "donut", kind: "dessert", labels: ["donut"], category: null, cuisine: null },
  { key: "baked_sweets", kind: "dessert", labels: ["cookie", "muffin", "pie"], category: null, cuisine: null },
];

// Jev に見せる選択肢の説明（英語で一言）。
export const CATEGORIES: Record<CategoryKey, string> = {
  noodles: "noodle dishes such as ramen, udon, soba, pasta",
  rice_dish: "rice dishes such as rice bowls, sushi, curry rice, fried rice",
  bread: "bread, sandwiches, burgers, toast",
  meat: "meat dishes such as steak, grilled meat, pork cutlet",
  seafood: "fish or seafood dishes such as sashimi, grilled fish, shrimp",
  fried: "deep-fried food such as tempura, fried chicken, croquettes",
  egg: "egg dishes such as omelette, fried egg, tamagoyaki",
  vegetables: "salad or vegetable dishes",
  soup: "soups such as miso soup, stew, pot dishes",
};

export const CUISINES: Record<CuisineKey, string> = {
  japanese: "Japanese cuisine",
  western: "Western cuisine (American, Italian, French)",
  chinese: "Chinese cuisine",
  korean: "Korean cuisine",
  ethnic: "other Asian or ethnic cuisine (Thai, Indian, Vietnamese, Mexican)",
};

// しきい値。LABEL_MIN・STRONG_MIN・DISH_LABEL_MIN は Vision の確信度、GENRE_MIN・TAG_MIN は Jev の probabilities[choice]（0〜1）と比べる。
// 2026-09-26 に Issue #80 の 7 例を Vercel AI Gateway 経由で流して決めた。例と結果は docs/plans/suggestion-worker.plan.md「決めたこと」。

// これ未満のラベルは捨てて Jev に見せない。雑多な低いラベル（机・食器など）で判断がぶれないように。
// 0.05：うどんの例の chopsticks 0.08 のような弱い手がかりは残したい。0.03 の table だけの例は Jev を呼ばずに提案なしにできた。
export const LABEL_MIN = 0.05;
// これ以上を「強い」、未満を「弱い」として Jev に伝える。
// 0.30：うどんの例（最大 0.22、全部「弱い」）でも Jev は food 0.97・noodles 0.87 を返したので、弱い扱いでも推せる。料理名のラベル（0.55〜0.8）は「強い」に入る。
export const STRONG_MIN = 0.3;
// 料理のタグを付けるのに要る、対応するラベルの確信度。料理のタグは、対応するラベルが一番強い 1 つだけを付ける。
// 0.15（#114。0.30 から下げた）：こうせいの写真 77 枚で数えた（ジャンルは正解を使った）。
// - 0.30 以上を全部付ける（直す前）：料理のタグが付くのは 34 枚。2 つ以上付く写真が 5 枚（ラーメン＋パスタなど）
// - 0.15 に下げて一番強い 1 つに絞る：46 枚・2 つ以上は 0 枚
// - さらにジャンルと種類が違うタグを除く：42 枚
// - さらにパスタだけ 0.30 にする（PASTA_LABEL_MIN）：39 枚
// 写っていない料理名は 0.1〜0.2 で出る（うどんに ramen 0.14）ので、0.15 未満は付けない。
// ラベルは scripts/real-labels.tsv と、作業用のメモ（photos-0927）。
export const DISH_LABEL_MIN = 0.15;
// おまかせ（アプリが自信のある写真を勝手に仕分ける）に回してよい根拠の強さ。
// Vision の食べ物系のラベル（GENERAL_FOOD_LABELS）の最大がこれ未満なら、ジャンルは返すが genreConfidence を null にする。
// 0.30（#114）：Jev はラベルが弱くても food 0.97 のように言い切るので、Jev の確率だけでは任せられない。
// こうせいの写真 77 枚で、食べ物・飲み物・デザートの 66 枚中 59 枚は残り、料理でない画像は 1 枚も通らなかった。
export const AUTO_EVIDENCE_MIN = 0.3;
export const GENERAL_FOOD_LABELS = ["food", "drink", "beverage", "dessert", "baked_goods"];
// Jev のジャンルの probabilities[choice] がこれ未満なら提案しない。
// 0.50：7 例の答えは 0.97〜1.0（食べ物でない例は other 1.0）と偏っていて、0.5〜0.9 のどこでも結果は同じ。4 択で「残り全部より高い」意味の 0.5 にした。
export const GENRE_MIN = 0.5;
// Jev の大分類・系統の probabilities[choice] がこれ未満なら足さない。
// 0.50：正しい答えは 0.87〜1.0、迷ったときは none 側に寄る（うどんの cuisine：none 0.56）ので、none 以外で 0.5 を超えたものだけ足せば十分。
export const TAG_MIN = 0.5;
