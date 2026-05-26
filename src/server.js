// Simple server bootstrap placeholder
const http = require('http');
const app = require('./app');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('NumLab AI server placeholder');
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
