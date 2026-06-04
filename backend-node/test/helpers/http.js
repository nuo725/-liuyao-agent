// HTTP Test Helper
// Wraps supertest-like functionality using native fetch for Node test runner.

/**
 * Create a lightweight HTTP test client bound to a running Express app.
 * Uses native Node http module instead of supertest to reduce dependencies.
 *
 * Usage:
 *   const server = app.listen(0);
 *   const { port } = server.address();
 *   const client = createHttpClient(port);
 *   const res = await client.get('/api/v1/health');
 *   server.close();
 */
function createHttpClient(port, baseUrl = '') {
  const base = `http://127.0.0.1:${port}${baseUrl}`;

  async function request(method, path, { body, headers = {} } = {}) {
    const url = `${base}${path}`;
    const opts = {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
    };
    if (body && method !== 'GET') {
      opts.body = JSON.stringify(body);
    }

    const res = await fetch(url, opts);
    const contentType = res.headers.get('content-type') || '';
    let data;
    if (contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }

    return {
      status: res.status,
      headers: res.headers,
      body: data,
    };
  }

  return {
    get: (path, opts) => request('GET', path, opts),
    post: (path, opts) => request('POST', path, opts),
    put: (path, opts) => request('PUT', path, opts),
    delete: (path, opts) => request('DELETE', path, opts),
  };
}

/**
 * Start an Express app on a random port and return { server, port, client }.
 */
async function startTestApp(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, '127.0.0.1', () => {
      const { port } = server.address();
      const client = createHttpClient(port);
      resolve({ server, port, client });
    });
  });
}

/**
 * Close a test server.
 */
async function stopTestApp(server) {
  return new Promise((resolve) => {
    if (server) server.close(resolve);
    else resolve();
  });
}

module.exports = { createHttpClient, startTestApp, stopTestApp };
