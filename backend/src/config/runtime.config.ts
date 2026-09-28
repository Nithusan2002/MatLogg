export type RuntimeConfig = {
  isProduction: boolean;
  port: number;
  trustProxyHops: number;
  corsAllowedOrigins: string[];
  swaggerEnabled: boolean;
};

function integerSetting(
  environment: NodeJS.ProcessEnv,
  name: string,
  fallback: number,
  minimum: number,
  maximum: number,
): number {
  const rawValue = environment[name]?.trim();
  if (!rawValue) return fallback;

  const value = Number(rawValue);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer between ${minimum} and ${maximum}`);
  }
  return value;
}

function allowedOrigins(environment: NodeJS.ProcessEnv, isProduction: boolean): string[] {
  const origins = (environment.CORS_ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

  for (const origin of origins) {
    let url: URL;
    try {
      url = new URL(origin);
    } catch {
      throw new Error('CORS_ALLOWED_ORIGINS must contain comma-separated origins');
    }

    if (url.origin !== origin || (isProduction && url.protocol !== 'https:')) {
      throw new Error('CORS_ALLOWED_ORIGINS must contain exact HTTPS origins in production');
    }
  }

  return origins;
}

export function runtimeConfig(environment: NodeJS.ProcessEnv = process.env): RuntimeConfig {
  const nodeEnvironment = environment.NODE_ENV?.trim() || 'development';
  if (!['development', 'test', 'production'].includes(nodeEnvironment)) {
    throw new Error('NODE_ENV must be development, test, or production');
  }

  const isProduction = nodeEnvironment === 'production';
  if (isProduction) {
    const databaseUrl = environment.DATABASE_URL?.trim();
    if (!databaseUrl) {
      throw new Error('DATABASE_URL must be configured in production');
    }

    const jwtSecret = environment.JWT_SECRET?.trim();
    if (!jwtSecret || jwtSecret.length < 32) {
      throw new Error('JWT_SECRET must be at least 32 characters in production');
    }
  }

  return {
    isProduction,
    port: integerSetting(environment, 'PORT', 4000, 1, 65_535),
    trustProxyHops: integerSetting(environment, 'TRUST_PROXY_HOPS', 0, 0, 10),
    corsAllowedOrigins: allowedOrigins(environment, isProduction),
    swaggerEnabled: !isProduction || environment.SWAGGER_ENABLED === 'true',
  };
}
