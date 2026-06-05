const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { createLogger } = require('../../src/shared/logger');

describe('Logger module', () => {
  it('createLogger returns a logger instance', () => {
    const logger = createLogger('test');
    assert.ok(logger, 'should return logger');
    assert.equal(typeof logger.info, 'function', 'should have info method');
    assert.equal(typeof logger.error, 'function', 'should have error method');
    assert.equal(typeof logger.warn, 'function', 'should have warn method');
    assert.equal(typeof logger.debug, 'function', 'should have debug method');
  });

  it('logger can log messages without throwing', () => {
    const logger = createLogger('test-module');
    assert.doesNotThrow(() => {
      logger.info('test message');
      logger.info({ key: 'value' }, 'test with data');
    });
  });

  it('logger can log errors without throwing', () => {
    const logger = createLogger('test-error');
    assert.doesNotThrow(() => {
      logger.error({ err: new Error('test') }, 'error occurred');
    });
  });

  it('createLogger accepts module name', () => {
    const logger = createLogger('my-module');
    assert.ok(logger, 'should create logger with module name');
  });

  it('createLogger works with empty module name', () => {
    const logger = createLogger('');
    assert.ok(logger, 'should create logger with empty name');
  });
});
