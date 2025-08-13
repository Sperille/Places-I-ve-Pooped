//
//  push-worker.js
//  Places I've Pooped
//
//  Created by Steven Perille on 8/4/25.
//

import { env } from 'cloudflare:env'

export default {
  async fetch(request, env, ctx) {
    if (request.method !== 'POST') {
      return new Response('Only POST allowed', { status: 405 });
    }

    const body = await request.json();

    const deviceTokens = body.tokens;
    const alertBody = body.message || "🚽 Someone just dropped a poop!";
    const poopID = body.poopID || null;

    const jwt = await createJWT(env.APNS_KEY, env.APNS_KEY_ID, env.TEAM_ID);

    const promises = deviceTokens.map(token => {
      return sendPush(token, jwt, env.BUNDLE_ID, alertBody, poopID);
    });

    await Promise.all(promises);

    return new Response("Notifications sent!", { status: 200 });
  }
};

async function createJWT(p8Key, keyId, teamId) {
  const encoder = new TextEncoder();
  const header = { alg: "ES256", kid: keyId };
  const claims = {
    iss: teamId,
    iat: Math.floor(Date.now() / 1000)
  };

  const base64url = input => {
    return btoa(JSON.stringify(input))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');
  };

  const headerBase64 = base64url(header);
  const claimsBase64 = base64url(claims);
  const data = `${headerBase64}.${claimsBase64}`;


  return data + ".<signature>";
}

async function sendPush(token, jwt, bundleId, alert, poopID) {
  const url = `https://api.sandbox.push.apple.com/3/device/${token}`;
  const headers = {
    "Authorization": `bearer ${jwt}`,
    "apns-topic": bundleId,
    "Content-Type": "application/json"
  };
  const payload = {
    aps: {
      alert,
      sound: "default",
      badge: 1,
      category: "POOP_UPDATE"
    },
    poopID
  };
  return fetch(url, {
    method: "POST",
    headers,
    body: JSON.stringify(payload)
  });
}
