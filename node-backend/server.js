const http = require("node:http");
const os = require("node:os");

const BACKEND = process.env.BACKEND_ID || "A";
const PORT = Number(
  process.env.PORT || (BACKEND === "A" ? 3001 : 3002)
);

const CACHE_DATA = {
  project: "Private Network Service Platform",
  message: "Caching demonstration",
  version: 1
};

const ETAG = '"cn-project-v1"';

function sendJSON(req, res, status, data, extraHeaders = {}) {
  const body = JSON.stringify(data);

  res.writeHead(status, {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(body),
    "X-Backend": BACKEND,
    "X-Content-Type-Options": "nosniff",
    ...extraHeaders
  });

  res.end(req.method === "HEAD" ? undefined : body);
}

const server = http.createServer((req, res) => {
  if (!["GET", "HEAD"].includes(req.method)) {
    return sendJSON(req, res, 405, {
      error: "Method not allowed"
    });
  }

  const path = new URL(
    req.url,
    "http://localhost"
  ).pathname;

  if (path === "/") {
    return sendJSON(req, res, 200, {
      backend: BACKEND,
      status: "running",
      hostname: os.hostname(),
      message: "Welcome to our CN project"
    });
  }

  if (path === "/api/status") {
    return sendJSON(req, res, 200, {
      backend: BACKEND,
      status: "ok",
      hostname: os.hostname(),
      port: PORT
    }, {
      "Cache-Control": "no-store"
    });
  }

  if (path === "/health") {
    return sendJSON(req, res, 200, {
      backend: BACKEND,
      status: "healthy"
    }, {
      "Cache-Control": "no-store"
    });
  }

  if (path === "/api/info") {
    const headers = {
      "Cache-Control": "public, max-age=30",
      "ETag": ETAG
    };

    if (req.headers["if-none-match"] === ETAG) {
      res.writeHead(304, {
        ...headers,
        "X-Backend": BACKEND
      });
      return res.end();
    }

    return sendJSON(req, res, 200, CACHE_DATA, headers);
  }

  return sendJSON(req, res, 404, {
    error: "Not found"
  });
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(
    `Backend ${BACKEND} running on 0.0.0.0:${PORT}`
  );
});

server.on("error", (err) => {
  console.error("Server error:", err.message);
  process.exit(1);
});
