// Zhouyi Backend - Error Handler Middleware (BE-005)

const { ApiError } = require('../shared/api-error');
const { fail } = require('../shared/response');
const { createLogger } = require('../shared/logger');

const logger = createLogger('error');

function errorHandler(err, req, res, _next) {
  // ApiError — expected business error
  if (err instanceof ApiError) {
    return res.status(err.statusCode).json({
      ...fail(err.code, err.message),
      requestId: req.requestId,
    });
  }

  // Unexpected error
  logger.error({ err, requestId: req.requestId }, 'Unhandled error');
  return res.status(500).json({
    ...fail('50000', 'Internal server error'),
    requestId: req.requestId,
  });
}

module.exports = { errorHandler };
