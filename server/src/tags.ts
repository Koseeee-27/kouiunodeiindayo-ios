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

export interface DishTag {
  key: string;
  labels: string[];
  category: CategoryKey | null;
  cuisine: CuisineKey | null;
}

export const DISH_TAGS: DishTag[] = [
  { key: "ramen", labels: ["ramen"], category: "noodles", cuisine: "chinese" },
  { key: "pasta", labels: ["pasta", "spaghetti"], category: "noodles", cuisine: "western" },
  { key: "sushi", labels: ["sushi"], category: "rice_dish", cuisine: "japanese" },
  { key: "curry", labels: ["curry"], category: "rice_dish", cuisine: null },
  { key: "gyoza", labels: ["gyoza", "dumpling"], category: null, cuisine: "chinese" },
  { key: "tempura", labels: ["tempura"], category: "fried", cuisine: "japanese" },
  { key: "karaage", labels: ["fried_chicken"], category: "fried", cuisine: null },
  { key: "pizza", labels: ["pizza"], category: null, cuisine: "western" },
  { key: "hamburger", labels: ["hamburger"], category: "bread", cuisine: "western" },
  { key: "steak", labels: ["steak"], category: "meat", cuisine: "western" },
  { key: "sandwich", labels: ["sandwich"], category: "bread", cuisine: "western" },
  { key: "coffee", labels: ["coffee"], category: null, cuisine: null },
  { key: "tea", labels: ["tea_drink"], category: null, cuisine: null },
  {
    key: "alcohol",
    labels: ["beer", "wine", "red_wine", "white_wine", "sparkling_wine", "cocktail", "liquor"],
    category: null,
    cuisine: null,
  },
  { key: "juice", labels: ["juice", "smoothie"], category: null, cuisine: null },
  { key: "bubble_tea", labels: ["bubble_tea"], category: null, cuisine: null },
  {
    key: "cake",
    labels: ["cake", "cake_regular", "birthday_cake", "cheesecake", "cupcake"],
    category: null,
    cuisine: null,
  },
  { key: "ice_cream", labels: ["ice_cream"], category: null, cuisine: null },
  { key: "donut", labels: ["donut"], category: null, cuisine: null },
  { key: "baked_sweets", labels: ["cookie", "muffin", "pie"], category: null, cuisine: null },
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

// しきい値。すべて Vision の確信度か Jev の confidence（0〜1）と比べる。
// 今は仮の値。wrangler dev で Issue #80 の例を試して直す（試した例と結果は PR に書く）。

// これ未満のラベルは捨てて Jev に見せない。雑多な低いラベル（机・食器など）で判断がぶれないように。
export const LABEL_MIN = 0.05;
// これ以上を「強い」、未満を「弱い」として Jev に伝える。
export const STRONG_MIN = 0.3;
// 料理のタグを付けるのに要る、対応するラベルの確信度。弱すぎる料理名で決めつけないように。
export const DISH_LABEL_MIN = 0.1;
// Jev のジャンルの confidence がこれ未満なら提案しない。
export const GENRE_MIN = 0.5;
// Jev の大分類・系統の confidence がこれ未満なら足さない。
export const TAG_MIN = 0.5;
