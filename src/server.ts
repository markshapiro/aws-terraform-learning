import { createServer } from "node:http";

const port = Number(process.env.PORT ?? 3000);

const server = createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify({ status: "ok" }));
    return;
  }

  res.writeHead(200, { "content-type": "text/plain" });
  res.end("Hello, World!\n");
});

server.listen(port, () => {
  console.log(`Server listening on http://0.0.0.0:${port}`);
});
