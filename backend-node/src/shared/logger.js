// Zhouyi Backend - Structured Logger (BE-008)
// Pino-based structured logging with request ID support.
// Sensitive fields (token, phone, password, question) are redacted.

const pino = require('pino');
const { getEnv } = require('../config/env');

let _rootLogger = null;

function getRootLogger() {
  if (_rootLogger) return _rootLogger;
  const env = getEnv();
  _rootLogger = pino({
    level: env.LOG_LEVEL,
    transport: env.NODE_ENV === 'development'
      ? { target: 'pino-pretty', options: { colorize: true, translateTime: 'SYS:HH:MM:ss' } }
      : undefined,
    redact: {
      paths: ['req.headers.authorization', 'body.token', 'body.phone', 'body.code',
        'body.password', 'body.newPassword', 'body.confirmPassword', 'body.question',
        '*.token', '*.phone', '*.code', '*.password', '*.question'],
      censor: '[REDACTED]',
    },
    serializers: {
      req: pino.stdSerializers.req,
      res: pino.stdSerializers.res,
      err: pino.stdSerializers.err,
    },
  });
  return _rootLogger;
}

function createLogger(module) {
  return getRootLogger().child({ module });
}

module.exports = { createLogger, getRootLogger };
