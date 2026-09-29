/**
 * backend-b/server.js
 * ====================
 * Phase 1 — Private Network Service Platform
 * Backend B  |  Node.js built-ins only  |  Port 3002
 *
 * Endpoints:
 *   GET /            → 200 JSON  { backend: "B", message: "Hello from Backend B" }
 *   GET /api/status  → 200 JSON  { backend: "B", status: "ok" }
 *   Any other path   → 404 JSON  { error: "not found", path: "..." }
 *
 * Headers added to every response:
 *   X-Backend:     B
 *   Cache-Control: max-age=60
 */

'use strict';

const http = require('http');

const HOST = '0.0.0.0';
const PORT = 3002;

/**
 * Build and send a JSON response.
 * @param {http.ServerResponse} res
 * @param {number} statusCode
 * @param {object} body
 */
function sendJSON(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type':  'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
    'X-Backend':     'B',
    'Cache-Control': 'max-age=60',
  });
  res.end(payload);
}

const server = http.createServer((req, res) => {
  // Log each request to stdout
  const ts = new Date().toISOString();
  console.log(`[Backend B] ${ts} ${req.method} ${req.url}`);

  // Only handle GET
  if (req.method !== 'GET') {
    return sendJSON(res, 405, { error: 'method not allowed' });
  }

  switch (req.url) {
    case '/':
      return sendJSON(res, 200, {
        backend: 'B',
        message: 'Hello from Backend B',
      });

    case '/api/status':
      return sendJSON(res, 200, {
        backend: 'B',
        status: 'ok',
      });

    default:
      return sendJSON(res, 404, {
        error: 'not found',
        path: req.url,
      });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`Backend B running on ${HOST}:${PORT}`);
  console.log('Endpoints: GET /   GET /api/status');
  console.log('Press Ctrl-C to stop.');
});
