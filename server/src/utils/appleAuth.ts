import { jwtVerify, createRemoteJWKSet } from 'jose';

const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';
const APPLE_ISSUER = 'https://appleid.apple.com';

const jwks = createRemoteJWKSet(new URL(APPLE_JWKS_URL));

interface AppleTokenPayload {
  sub: string;
  email?: string;
  email_verified?: string | boolean;
  is_private_email?: string | boolean;
}

/**
 * Verify an Apple Sign In identity token.
 * @param identityToken - The JWT token from Apple
 * @param clientId - The app's Bundle ID (audience)
 * @returns The decoded token payload containing the Apple user ID (sub)
 */
export async function verifyAppleToken(
  identityToken: string,
  clientId: string
): Promise<AppleTokenPayload> {
  const { payload } = await jwtVerify(identityToken, jwks, {
    issuer: APPLE_ISSUER,
    audience: clientId,
    clockTolerance: 60,
  });

  const sub = payload.sub;
  if (!sub) {
    throw new Error('Apple token missing sub claim');
  }

  return {
    sub,
    email: payload.email as string | undefined,
    email_verified: payload.email_verified as string | boolean | undefined,
    is_private_email: payload.is_private_email as string | boolean | undefined,
  };
}
