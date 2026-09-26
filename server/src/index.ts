// Worker の入口。受け渡しの形とエラーの決まりは docs/suggestion-api.md。
// 受け取った内容（ラベル・Jev の答え）はログに出さない（ADR 0006）。console.error はエラーの種類と例外のメッセージだけ。

import { BadRequestError, parseLabels, suggest } from "./suggest";

interface Env {
  AI: Ai;
  SUGGEST_TOKEN: string;
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
    // /search（機能28）は #85 で作る。それまでは 404。
    if (url.pathname !== "/suggest") {
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

    let labels;
    try {
      labels = parseLabels(body);
    } catch (error) {
      if (error instanceof BadRequestError) {
        return errorResponse(400, "bad_request", error.message);
      }
      throw error;
    }

    try {
      return json(await suggest(env.AI, labels));
    } catch (error) {
      console.error("upstream_failed", error instanceof Error ? error.message : String(error));
      return errorResponse(502, "upstream_failed", "model call failed");
    }
  },
} satisfies ExportedHandler<Env>;
