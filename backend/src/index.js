export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    // CORS headers
    const corsHeaders = {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };

    if (method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      let response;

      // Routes
      if (path === "/api/stocks" && method === "GET") {
        response = await getStocks(env);
      } else if (path.match(/^\/api\/stocks\/[\w]+$/) && method === "GET") {
        const symbol = path.split("/")[3];
        response = await getStock(env, symbol);
      } else if (path.match(/^\/api\/stocks\/[\w]+\/history$/) && method === "GET") {
        const symbol = path.split("/")[3];
        const period = url.searchParams.get("period") || "1m";
        response = await getHistory(env, symbol, period);
      } else if (path === "/api/alerts" && method === "POST") {
        const body = await request.json();
        response = await createAlert(env, body);
      } else if (path === "/api/alerts" && method === "GET") {
        const userId = url.searchParams.get("user_id");
        response = await getAlerts(env, userId);
      } else if (path.match(/^\/api\/alerts\/\d+$/) && method === "DELETE") {
        const alertId = path.split("/")[3];
        response = await deleteAlert(env, alertId);
      } else if (path.match(/^\/api\/stocks\/[\w]+\/ai$/) && method === "GET") {
        const symbol = path.split("/")[3];
        response = await getAIInsight(env, symbol);
      } else if (path === "/api/scraper/prices" && method === "POST") {
        // Endpoint for scraper to push data
        const apiKey = request.headers.get("X-API-Key");
        if (apiKey !== env.SCRAPER_API_KEY) {
          return new Response("Unauthorized", { status: 401, headers: corsHeaders });
        }
        const body = await request.json();
        response = await savePrices(env, body);
      } else if (path === "/health") {
        response = { status: "ok", time: new Date().toISOString() };
      } else {
        return new Response("Not Found", { status: 404, headers: corsHeaders });
      }

      return new Response(JSON.stringify(response), {
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    } catch (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      });
    }
  },
};

// --- Route Handlers ---

async function getStocks(env) {
  // Try cache first
  const cached = await env.CACHE.get("latest_prices", "json");
  if (cached) return cached;

  // Get latest price for each stock
  const result = await env.DB.prepare(`
    SELECT s.symbol, s.name, s.sector, p.price, p.change_value, p.change_percent, p.volume, p.recorded_at
    FROM stocks s
    LEFT JOIN stock_prices p ON s.symbol = p.symbol
    AND p.recorded_at = (SELECT MAX(recorded_at) FROM stock_prices WHERE symbol = s.symbol)
    ORDER BY s.symbol
  `).all();

  // Cache for 5 minutes
  await env.CACHE.put("latest_prices", JSON.stringify(result.results), { expirationTtl: 300 });
  return result.results;
}

async function getStock(env, symbol) {
  const result = await env.DB.prepare(`
    SELECT s.symbol, s.name, s.sector, p.price, p.change_value, p.change_percent, p.volume, p.recorded_at
    FROM stocks s
    LEFT JOIN stock_prices p ON s.symbol = p.symbol
    AND p.recorded_at = (SELECT MAX(recorded_at) FROM stock_prices WHERE symbol = s.symbol)
    WHERE s.symbol = ?
  `).bind(symbol.toUpperCase()).first();

  if (!result) return { error: "Stock not found" };
  return result;
}

async function getHistory(env, symbol, period) {
  const days = { "1w": 7, "1m": 30, "3m": 90, "6m": 180, "1y": 365 }[period] || 30;
  const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

  const result = await env.DB.prepare(`
    SELECT price, change_percent, volume, recorded_at
    FROM stock_prices
    WHERE symbol = ? AND recorded_at >= ?
    ORDER BY recorded_at ASC
  `).bind(symbol.toUpperCase(), since).all();

  return result.results;
}

async function createAlert(env, body) {
  const { user_id, symbol, alert_type, target_value } = body;

  await env.DB.prepare(`
    INSERT INTO alerts (user_id, symbol, alert_type, target_value)
    VALUES (?, ?, ?, ?)
  `).bind(user_id, symbol.toUpperCase(), alert_type, target_value).run();

  return { message: "Alert created" };
}

async function getAlerts(env, userId) {
  const result = await env.DB.prepare(`
    SELECT id, symbol, alert_type, target_value, is_active, created_at
    FROM alerts WHERE user_id = ? AND is_active = 1
  `).bind(userId).all();

  return result.results;
}

async function deleteAlert(env, alertId) {
  await env.DB.prepare(`UPDATE alerts SET is_active = 0 WHERE id = ?`).bind(alertId).run();
  return { message: "Alert deleted" };
}

async function savePrices(env, prices) {
  // prices = [{ symbol, price, change_value, change_percent, volume }]
  const timestamp = new Date().toISOString();

  for (const p of prices) {
    await env.DB.prepare(`
      INSERT INTO stock_prices (symbol, price, change_value, change_percent, volume, recorded_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).bind(p.symbol, p.price, p.change_value || 0, p.change_percent || 0, p.volume || 0, timestamp).run();
  }

  // Check alerts
  const activeAlerts = await env.DB.prepare(
    `SELECT * FROM alerts WHERE is_active = 1`
  ).all();

  const triggeredAlerts = [];
  for (const alert of activeAlerts.results) {
    const priceData = prices.find(p => p.symbol === alert.symbol);
    if (!priceData) continue;

    let triggered = false;
    if (alert.alert_type === 'price_above' && priceData.price >= alert.target_value) {
      triggered = true;
    } else if (alert.alert_type === 'price_below' && priceData.price <= alert.target_value) {
      triggered = true;
    }

    if (triggered) {
      triggeredAlerts.push({
        ...alert,
        current_price: priceData.price
      });
      // Deactivate the alert after triggering
      await env.DB.prepare(
        `UPDATE alerts SET is_active = 0 WHERE id = ?`
      ).bind(alert.id).run();
    }
  }

  if (triggeredAlerts.length > 0) {
  for (const alert of triggeredAlerts) {
    const user = await env.DB.prepare(
      `SELECT fcm_token FROM users WHERE id = ?`
    ).bind(alert.user_id).first();

    if (user && user.fcm_token) {
      const direction = alert.alert_type === 'price_above' ? 'risen above' : 'dropped below';
      await sendPushNotification(
        env,
        user.fcm_token,
        `${alert.symbol} Alert`,
        `${alert.symbol} has ${direction} GHS ${alert.target_value}. Current price: GHS ${alert.current_price}`
      );
    }
  }
}

  await env.CACHE.delete("latest_prices");
  return { message: `Saved ${prices.length} prices, triggered ${triggeredAlerts.length} alerts` };

  // Clear cache so next request gets fresh data
  await env.CACHE.delete("latest_prices");
  return { message: `Saved ${prices.length} prices` };
}

async function getAIInsight(env, symbol) {
  // Check cache (AI insights cached for 1 hour)
  const cacheKey = `ai_${symbol}`;
  const cached = await env.CACHE.get(cacheKey);
  if (cached) return JSON.parse(cached);

  // Get recent prices for analysis
  const history = await env.DB.prepare(`
    SELECT price, recorded_at FROM stock_prices
    WHERE symbol = ? ORDER BY recorded_at DESC LIMIT 60
  `).bind(symbol.toUpperCase()).all();

  if (history.results.length < 5) {
    return { recommendation: "HOLD", reason: "Not enough data yet for analysis", confidence: 0 };
  }

  const prices = history.results.map(r => r.price).reverse();

  // Simple technical analysis
  const sma20 = prices.slice(-20).reduce((a, b) => a + b, 0) / Math.min(20, prices.length);
  const currentPrice = prices[prices.length - 1];
  const priceChange = ((currentPrice - prices[0]) / prices[0]) * 100;

  // RSI calculation (simplified)
  let gains = 0, losses = 0;
  for (let i = 1; i < prices.length; i++) {
    const diff = prices[i] - prices[i - 1];
    if (diff > 0) gains += diff;
    else losses += Math.abs(diff);
  }
  const rs = gains / (losses || 1);
  const rsi = 100 - (100 / (1 + rs));

  // Build signals
  const signals = [];
  if (currentPrice > sma20) signals.push("Price above moving average (bullish)");
  else signals.push("Price below moving average (bearish)");
  if (rsi > 70) signals.push("Overbought territory (consider selling)");
  else if (rsi < 30) signals.push("Oversold territory (consider buying)");
  if (priceChange > 5) signals.push(`Up ${priceChange.toFixed(1)}% recently`);
  else if (priceChange < -5) signals.push(`Down ${Math.abs(priceChange).toFixed(1)}% recently`);

  // Call Gemini for natural language insight
  let aiText = "";
  try {
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: `You are a Ghana Stock Exchange analyst. Stock: ${symbol}. Current price: GHS ${currentPrice}. Technical signals: ${signals.join(", ")}. RSI: ${rsi.toFixed(0)}. Price trend: ${priceChange.toFixed(1)}% over the period. Give a 2-3 sentence recommendation (BUY/HOLD/SELL) with brief reasoning. End with a one-line disclaimer.`
            }]
          }]
        })
      }
    );
    const geminiData = await geminiResponse.json();
    aiText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "";
  } catch (e) {
    aiText = `Based on technical indicators: ${signals.join(". ")}. This is not financial advice.`;
  }

  const result = {
    symbol,
    current_price: currentPrice,
    rsi: Math.round(rsi),
    signals,
    recommendation: rsi < 30 ? "BUY" : rsi > 70 ? "SELL" : "HOLD",
    ai_insight: aiText,
    generated_at: new Date().toISOString()
  };

  // Cache for 1 hour
  await env.CACHE.put(cacheKey, JSON.stringify(result), { expirationTtl: 3600 });
  return result;

async function sendPushNotification(env, fcmToken, title, body) {
  try {
    // Decode service account
    const serviceAccountJson = atob(env.FIREBASE_SERVICE_ACCOUNT);
    const serviceAccount = JSON.parse(serviceAccountJson);

    // Get access token
    const accessToken = await getFirebaseAccessToken(serviceAccount);

    // Send notification using V1 API
    const projectId = serviceAccount.project_id;
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: title,
              body: body,
            },
          },
        }),
      }
    );

    const result = await response.json();
    if (!response.ok) {
      console.error('FCM error:', result);
    }
  } catch (e) {
    console.error('Failed to send push notification:', e);
  }
}

async function getFirebaseAccessToken(serviceAccount) {
  // Create JWT
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  };

  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // Sign with RSA private key
  const privateKey = serviceAccount.private_key;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedToken)
  );

  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const jwt = `${unsignedToken}.${encodedSignature}`;

  // Exchange JWT for access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

function pemToArrayBuffer(pem) {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\n/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function saveFcmToken(env, body) {
  const { user_id, fcm_token } = body;
  await env.DB.prepare(
    `UPDATE users SET fcm_token = ? WHERE id = ?`
  ).bind(fcm_token, user_id).run();
  return { message: "Token saved" };
}

}