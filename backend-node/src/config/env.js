// Zhouyi Backend - Environment Configuration (BE-002)
// Validates required variables at startup; fails fast if missing.

require('dotenv').config();
const { z } = require('zod');

const envSchema = z.object({
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LOG_LEVEL: z.enum(['trace', 'debug', 'info', 'warn', 'error', 'fatal']).default('info'),

  DATABASE_URL: z.string().min(1).refine(
    (v) => v.startsWith('postgresql://') || v.startsWith('postgres://'),
    'Must be a PostgreSQL connection string'
  ),

  JWT_SECRET: z.string().min(32),
  JWT_ACCESS_TTL: z.coerce.number().default(7200),       // 2 hours
  JWT_REFRESH_TTL: z.coerce.number().default(2592000),   // 30 days

  SMS_PROVIDER: z.enum(['test', 'aliyun', 'twilio']).default('test'),
  SMS_API_KEY: z.string().optional().default(''),
  SMS_API_SECRET: z.string().optional().default(''),

  PAYMENT_CALLBACK_SECRET: z.string().default('dev_callback_secret'),

  LIUYAO_AGENT_URL: z.string().optional().default('').refine(
    (v) => v === '' || v.startsWith('http'),
    'Must be a valid URL or empty'
  ),
  LIUYAO_AGENT_TOKEN: z.string().optional().default(''),
});

let _env = null;

function getEnv() {
  if (_env) return _env;
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    console.error('❌ Invalid environment configuration:');
    for (const issue of result.error.issues) {
      console.error(`  ${issue.path.join('.')}: ${issue.message}`);
    }
    process.exit(1);
  }
  _env = result.data;
  return _env;
}

module.exports = { getEnv };
