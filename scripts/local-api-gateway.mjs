import http from "node:http";
import { Readable } from "node:stream";

const LISTEN_HOST = "0.0.0.0";
const LISTEN_PORT = 3001;
const TARGET_ORIGIN = "https://hormony-ruddy.vercel.app";
const MAX_BODY_BYTES = 256 * 1024;
const REQUEST_TIMEOUT_MS = 120_000;

function sendJson(response, status, payload) {
  response.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    request.on("data", (chunk) => {
      size += chunk.length;
      if (size > MAX_BODY_BYTES) {
        reject(new Error("REQUEST_BODY_TOO_LARGE"));
        request.destroy();
        return;
      }
      chunks.push(chunk);
    });
    request.on("end", () => resolve(Buffer.concat(chunks)));
    request.on("error", reject);
  });
}

const server = http.createServer(async (request, response) => {
  const startedAt = Date.now();
  const requestUrl = new URL(request.url ?? "/", TARGET_ORIGIN);
  if (!requestUrl.pathname.startsWith("/api/")) {
    sendJson(response, 404, { error: "仅允许代理项目 API", code: "NOT_FOUND" });
    return;
  }

  try {
    const body = request.method === "GET" || request.method === "HEAD"
      ? undefined
      : await readBody(request);
    const upstream = await fetch(new URL(requestUrl.pathname + requestUrl.search, TARGET_ORIGIN), {
      method: request.method,
      headers: {
        "Content-Type": request.headers["content-type"] ?? "application/json",
        Accept: request.headers.accept ?? "application/json",
      },
      body: body?.length ? body : undefined,
      redirect: "manual",
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });

    const headers = {};
    for (const name of ["content-type", "cache-control"]) {
      const value = upstream.headers.get(name);
      if (value) headers[name] = value;
    }
    response.writeHead(upstream.status, headers);
    if (upstream.body) {
      Readable.fromWeb(upstream.body).pipe(response);
    } else {
      response.end();
    }
    process.stdout.write(
      `[local-gateway] ${request.method} ${requestUrl.pathname} -> ${upstream.status} ${Date.now() - startedAt}ms\n`
    );
  } catch (error) {
    const code = error instanceof Error && error.message === "REQUEST_BODY_TOO_LARGE"
      ? "REQUEST_BODY_TOO_LARGE"
      : "UPSTREAM_UNAVAILABLE";
    const status = code === "REQUEST_BODY_TOO_LARGE" ? 413 : 502;
    sendJson(response, status, {
      error: status === 413 ? "请求体过大" : "本地网关无法连接线上服务",
      code,
    });
    process.stderr.write(
      `[local-gateway] ${request.method} ${requestUrl.pathname} -> ${status} ${Date.now() - startedAt}ms\n`
    );
  }
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
  process.stdout.write(
    `[local-gateway] listening on http://${LISTEN_HOST}:${LISTEN_PORT}, target=${TARGET_ORIGIN}\n`
  );
});
