// ============================================================
// Shared FCM HTTP v1 helpers — used by every notify-* edge
// function so the JWT-mint + send logic lives in exactly one
// place.
//
// Google shut down the legacy /fcm/send endpoint in June 2024,
// so all push delivery now goes through the v1 messaging API
// at https://fcm.googleapis.com/v1/projects/<id>/messages:send.
// That endpoint takes an OAuth bearer token issued from a
// Firebase service account, so each invocation needs to:
//   1. Sign a JWT with the SA's private key.
//   2. Exchange the JWT for an access token at
//      oauth2.googleapis.com/token.
//   3. POST the message with the access token in the
//      Authorization header.
//
// The access token is good for an hour. We cache it in module
// scope so a warm container only mints once per hour even if
// it processes many webhooks.
// ============================================================

import {
  SignJWT,
  importPKCS8,
} from 'https://deno.land/x/jose@v5.9.6/index.ts';

export interface FcmServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

/// Tagged result for [sendFcmMessage] — lets callers tally
/// delivered vs failed without inspecting HTTP responses
/// themselves.
export interface FcmSendResult {
  ok: boolean;
  status: number;
  body?: string;
}

/// Cached access token. Keyed off the service account's client
/// email so the cache is correct even if a function is somehow
/// invoked with multiple SAs (defensive — we only ever use one
/// today).
let cachedToken:
  | { value: string; expiresAt: number; sa: string }
  | null = null;

/// Read FCM_SERVICE_ACCOUNT from env and parse. Returns null if
/// the secret is unset or malformed; callers treat null as
/// "scaffold mode" and log without throwing.
export function readServiceAccount(): FcmServiceAccount | null {
  const raw = Deno.env.get('FCM_SERVICE_ACCOUNT');
  if (!raw) return null;
  try {
    return JSON.parse(raw) as FcmServiceAccount;
  } catch (e) {
    console.error('[fcm] FCM_SERVICE_ACCOUNT is not valid JSON', e);
    return null;
  }
}

/// Mint (or return cached) FCM-scoped OAuth access token.
export async function mintAccessToken(
  sa: FcmServiceAccount,
): Promise<string | null> {
  const now = Date.now();
  if (
    cachedToken &&
    cachedToken.sa === sa.client_email &&
    cachedToken.expiresAt > now + 60_000
  ) {
    return cachedToken.value;
  }

  try {
    const privateKey = await importPKCS8(sa.private_key, 'RS256');
    const jwt = await new SignJWT({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
    })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
      .setIssuedAt()
      .setExpirationTime('1h')
      .sign(privateKey);

    const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    if (!tokenRes.ok) {
      const errBody = await tokenRes.text();
      console.error(
        `[fcm] OAuth token mint failed (${tokenRes.status}): ${errBody}`,
      );
      return null;
    }

    const data = (await tokenRes.json()) as {
      access_token: string;
      expires_in: number;
    };

    cachedToken = {
      value: data.access_token,
      // Refresh 5 minutes early to defend against clock drift.
      expiresAt: now + data.expires_in * 1000 - 5 * 60 * 1000,
      sa: sa.client_email,
    };

    return data.access_token;
  } catch (e) {
    console.error('[fcm] mintAccessToken failed', e);
    return null;
  }
}

/// FCM v1 message body. Caller passes notification + data; we
/// merge in the platform-specific collapse-id wrappers when a
/// collapseKey is provided so duplicate messages don't double-
/// banner the user.
export interface FcmMessage {
  /// FCM device token (what `FirebaseMessaging.instance.getToken()`
  /// hands you on the client).
  token: string;
  notification: {
    title: string;
    body: string;
  };
  /// Custom data delivered alongside the notification — the
  /// client's PushNotificationService reads `data.route` and
  /// pushes to that GoRouter path on tap.
  data?: Record<string, string>;
  /// When set, FCM treats subsequent messages with the same key
  /// as updates: the OS replaces an existing banner instead of
  /// stacking a new one. Useful for status updates on the same
  /// row.
  collapseKey?: string;
}

/// POST a single FCM message. Returns { ok, status, body? } so
/// the caller can log or tally.
export async function sendFcmMessage(
  sa: FcmServiceAccount,
  accessToken: string,
  message: FcmMessage,
): Promise<FcmSendResult> {
  const endpoint =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  const body: Record<string, unknown> = {
    token: message.token,
    notification: message.notification,
  };
  if (message.data) body.data = message.data;
  if (message.collapseKey) {
    body.android = { collapse_key: message.collapseKey };
    body.apns = {
      headers: { 'apns-collapse-id': message.collapseKey },
    };
  }

  try {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message: body }),
    });
    const text = res.ok ? undefined : await res.text();
    return { ok: res.ok, status: res.status, body: text };
  } catch (e) {
    console.error('[fcm] sendFcmMessage threw', e);
    return { ok: false, status: 0, body: String(e) };
  }
}
