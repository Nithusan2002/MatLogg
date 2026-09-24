const insecureDevelopmentSecret = 'dev-secret';

export function jwtSecret(environment: NodeJS.ProcessEnv = process.env): string {
  const secret = environment.JWT_SECRET?.trim();
  if (!secret) {
    throw new Error('JWT_SECRET must be configured before the API can start');
  }
  if (environment.NODE_ENV === 'production' && secret === insecureDevelopmentSecret) {
    throw new Error('JWT_SECRET cannot use the development value in production');
  }
  return secret;
}

export function isDevLoginEnabled(environment: NodeJS.ProcessEnv = process.env): boolean {
  return environment.NODE_ENV !== 'production' && environment.DEV_LOGIN_ENABLED === 'true';
}
