// Zhouyi Backend - API Error (BE-005)

class ApiError extends Error {
  constructor(code, message, statusCode = 400, details = null) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }

  static badRequest(message = 'Invalid request payload', details = null) {
    return new ApiError('40001', message, 400, details);
  }

  static unauthorized(message = 'Authentication required') {
    return new ApiError('40101', message, 401);
  }

  static sessionExpired(message = 'Session expired') {
    return new ApiError('40102', message, 401);
  }

  static forbidden(message = 'Permission denied') {
    return new ApiError('40301', message, 403);
  }

  static notFound(message = 'Resource not found') {
    return new ApiError('40401', message, 404);
  }

  static conflict(message = 'Invalid state transition') {
    return new ApiError('40901', message, 409);
  }

  static rateLimited(message = 'Rate limit exceeded') {
    return new ApiError('42901', message, 429);
  }

  static internal(message = 'Internal server error') {
    return new ApiError('50000', message, 500);
  }

  static timeout(message = 'Upstream timeout') {
    return new ApiError('50401', message, 504);
  }
}

module.exports = { ApiError };
