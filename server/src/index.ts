// Worker の入口。受け渡しの形とエラーの決まりは docs/suggestion-api.md。
// 受け取った内容（ラベル・検索の言葉・Jev の答え・API キー）はログに出さない（ADR 0006・0007）。console.error はエラーの種類と例外のメッセージだけ。

import { parseQuery, search } from "./search";
import { BadRequestError, parseLabels, suggest } from "./suggest";

interface Env {
  SUGGEST_TOKEN: string;
  // Vercel AI Gateway の API キー（ADR 0007）。本番は wrangler secret put、手元は人が wrangler dev の --var で渡す（docs/setup.md）。
  AI_GATEWAY_API_KEY: string;
}

type ErrorCode = "bad_request" | "unauthorized" | "not_found" | "method_not_allowed" | "upstream_failed";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function errorResponse(status: number, code: ErrorCode, message: string): Response {
  return json({ error: { code, message } }, status);
}

// 両方を SHA-256 にして長さを揃えてから timingSafeEqual で比べる。比較にかかる時間から合言葉を推測されないため。
async function isAuthorized(request: Request, token: string | undefined): Promise<boolean> {
  const header = request.headers.get("Authorization");
  if (!token || !header?.startsWith("Bearer ")) {
    return false;
  }
  const encoder = new TextEncoder();
  const [given, expected] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(header.slice("Bearer ".length))),
    crypto.subtle.digest("SHA-256", encoder.encode(token)),
  ]);
  return crypto.subtle.timingSafeEqual(given, expected);
}

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname !== "/suggest" && url.pathname !== "/search") {
      return errorResponse(404, "not_found", "no such endpoint");
    }
    if (request.method !== "POST") {
      return errorResponse(405, "method_not_allowed", "use POST");
    }
    if (!(await isAuthorized(request, env.SUGGEST_TOKEN))) {
      return errorResponse(401, "unauthorized", "missing or invalid token");
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return errorResponse(400, "bad_request", "body must be JSON");
    }

    // 本文を読んで、Jev に聞く処理を決める。形が違えば 400（Jev は呼ばない）。
    let run: (apiKey: string) => Promise<unknown>;
    try {
      if (url.pathname === "/suggest") {
        const labels = parseLabels(body);
        run = (apiKey) => suggest(apiKey, labels);
      } else {
        const query = parseQuery(body);
        run = (apiKey) => search(apiKey, query);
      }
    } catch (error) {
      if (error instanceof BadRequestError) {
        return errorResponse(400, "bad_request", error.message);
      }
      throw error;
    }

    if (!env.AI_GATEWAY_API_KEY) {
      console.error("upstream_failed", "AI_GATEWAY_API_KEY not set");
      return errorResponse(502, "upstream_failed", "model call failed");
    }

    try {
      return json(await run(env.AI_GATEWAY_API_KEY));
    } catch (error) {
      console.error("upstream_failed", error instanceof Error ? error.message : String(error));
      return errorResponse(502, "upstream_failed", "model call failed");
    }
  },
} satisfies ExportedHandler<Env>;
