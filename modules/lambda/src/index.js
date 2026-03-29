exports.handler = async (event) => {
  const env = process.env.ENVIRONMENT || 'unknown';

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>My Website - ${env}</title>
  <style>
    body { font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #f0f4f8; }
    .card { background: white; padding: 2rem 3rem; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); text-align: center; }
    h1 { color: #2d3748; }
    .badge { display: inline-block; padding: 0.25rem 0.75rem; border-radius: 9999px; font-size: 0.875rem; font-weight: 600; background: #ebf8ff; color: #2b6cb0; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Hello from Lambda</h1>
    <p>This page is served via API Gateway + Lambda</p>
    <span class="badge">${env.toUpperCase()}</span>
  </div>
</body>
</html>`;

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'text/html' },
    body: html,
  };
};
