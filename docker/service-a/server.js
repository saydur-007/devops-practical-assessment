const express = require('express');
const pino = require('pino');
const { v4: uuidv4 } = require('uuid');

const logger = pino({ level: process.env.LOG_LEVEL || 'info' });
const app = express();
const SERVICE_NAME = 'service-a';

// Middleware to attach/generate request id and log requests
app.use((req, res, next) => {
  const incomingId = req.headers['x-request-id'] || req.headers['x_request_id'];
  const requestId = incomingId || uuidv4();
  req.requestId = requestId;

  const start = Date.now();

  res.setHeader('X-Request-Id', requestId);

  res.on('finish', () => {
    const duration = Date.now() - start;
    const logObj = {
      timestamp: new Date().toISOString(),
      level: res.statusCode >= 500 ? 'error' : 'info',
      service: SERVICE_NAME,
      request_id: requestId,
      method: req.method,
      path: req.originalUrl,
      status_code: res.statusCode,
      duration_ms: duration,
    };
    logger[logObj.level](logObj, 'request completed');
  });

  next();
});

app.get('/api/v1/health', (req, res) => {
  const body = { status: 'healthy', service: SERVICE_NAME };
  res.status(200).json(body);
});

app.get('/api/v1/users', (req, res) => {
  const users = [
    { id: 1, name: 'Alice', email: 'alice@example.com' },
    { id: 2, name: 'Bob', email: 'bob@example.com' }
  ];
  res.status(200).json({ users });
});

app.get('/api/v1/error', (req, res) => {
  const err = new Error('intentional error for testing');
  logger.error({
    timestamp: new Date().toISOString(),
    level: 'error',
    service: SERVICE_NAME,
    request_id: req.requestId,
    method: req.method,
    path: req.originalUrl,
    status_code: 500,
    message: err.message
  }, 'intentional error');
  res.status(500).json({ error: 'internal server error' });
});

const port = process.env.PORT || 3000;
app.listen(port, () => {
  logger.info({ service: SERVICE_NAME, port, message: 'service started' });
});
