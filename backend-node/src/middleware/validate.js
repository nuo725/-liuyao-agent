// Zhouyi Backend - Validation Middleware (BE-007)
// Zod-based request validation for body, query, and params.

const { ApiError } = require('../shared/api-error');

function validate(schema, source = 'body') {
  return (req, res, next) => {
    const data = source === 'body' ? req.body : source === 'query' ? req.query : req.params;
    const result = schema.safeParse(data);
    if (!result.success) {
      const details = result.error.issues.map(i => ({
        path: i.path.join('.'),
        message: i.message,
      }));
      throw ApiError.badRequest(details[0]?.message || 'Invalid request payload', details);
    }
    req.validated = req.validated || {};
    req.validated[source] = result.data;
    next();
  };
}

module.exports = { validate };
