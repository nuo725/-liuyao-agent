const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { currentWeekKey } = require('../../src/modules/analytics/service');

describe('Analytics metrics helpers', () => {
  it('builds ISO week keys', () => {
    assert.equal(currentWeekKey(new Date('2026-06-04T00:00:00.000Z')), '2026-W23');
  });
});
