// Rutin — IAP makbuz doğrulama Edge Function'ı.
//
// lib/iap.dart (_defaultVerify) buraya POST atar:
//   { source: 'app_store' | 'google_play', productId: string, receipt: string }
// ve `{ valid: boolean }` bekler. `valid: true` dönmeden Pro açılmaz.
//
// Deploy:
//   supabase functions deploy verify-receipt --no-verify-jwt
// (--no-verify-jwt gerekli: istemci bu isteği Authorization header'ı
//  olmadan atıyor; aksi halde Supabase gateway 401 ile reddeder.)
//
// Gerekli secret'lar (supabase secrets set ... ile):
//   GOOGLE_SERVICE_ACCOUNT_JSON  — Play Console'da "Android Publisher API"
//                                  yetkisi verilmiş servis hesabının tam
//                                  JSON anahtarı (tek satır string olarak).
//   GOOGLE_PACKAGE_NAME          — ör. com.alper.rutin (verilmezse bu
//                                  değere düşer, aşağıya bak).
//   APPLE_SHARED_SECRET          — App Store Connect → Uygulama →
//                                  Abonelikler → "Uygulamaya Özel Paylaşılan
//                                  Sır".
//
// Bu secret'lar olmadan fonksiyon deploy edilebilir ama ilgili mağaza için
// doğrulama her zaman `valid: false` döner (bkz. aşağıdaki kontroller).

import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const GOOGLE_PACKAGE_NAME =
  Deno.env.get("GOOGLE_PACKAGE_NAME") ?? "com.alper.rutin";
const GOOGLE_SERVICE_ACCOUNT_JSON = Deno.env.get("GOOGLE_SERVICE_ACCOUNT_JSON");
const APPLE_SHARED_SECRET = Deno.env.get("APPLE_SHARED_SECRET");

/// `kind` ürünün doğrulama tipini belirtir (bkz. lib/iap.dart → Iap.kindOf).
/// Abonelik ile tek seferlik ("ömür boyu") satın alma her iki mağazada da
/// TAMAMEN farklı doğrulanır; eski sürüm her ürünü abonelik sanıyordu ve bu
/// yüzden ömür boyu satın alma HİÇBİR ZAMAN doğrulanamıyordu.
/// Eski istemciler `kind` göndermez → 'subscription' varsayılır (geriye
/// dönük uyumlu).
type ProductKind = "subscription" | "lifetime";

interface VerifyBody {
  source?: string;
  productId?: string;
  receipt?: string;
  kind?: ProductKind;
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ valid: false, error: "method_not_allowed" }, 405);
  }

  let body: VerifyBody;
  try {
    body = await req.json();
  } catch {
    return json({ valid: false, error: "invalid_json" }, 400);
  }

  const { source, productId, receipt } = body;
  const kind: ProductKind = body.kind === "lifetime" ? "lifetime" : "subscription";
  if (!source || !productId || !receipt) {
    return json({ valid: false, error: "missing_fields" }, 400);
  }

  try {
    let valid = false;
    if (source === "google_play") {
      valid = kind === "lifetime"
        ? await verifyGooglePlayProduct(productId, receipt)
        : await verifyGooglePlaySubscription(productId, receipt);
    } else if (source === "app_store") {
      valid = kind === "lifetime"
        ? await verifyAppStoreLifetime(receipt, productId)
        : await verifyAppStoreSubscription(receipt);
    }
    return json({ valid });
  } catch (err) {
    // İstemci tarafı (iap.dart) yalnızca res.statusCode === 200 && body.valid
    // kontrolü yapıyor; beklenmeyen hatalarda da 200 + valid:false dönüp
    // kullanıcıya düzgün hata mesajı gösterilmesini sağlıyoruz.
    console.error("verify-receipt error:", err);
    return json({ valid: false, error: "verification_failed" }, 200);
  }
});

// ---------------------------------------------------------------------
// Google Play — Android Publisher API (purchases.subscriptions.get)
// ---------------------------------------------------------------------

function pemToBinary(pem: string): ArrayBuffer {
  const contents = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const raw = atob(contents);
  const buf = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) buf[i] = raw.charCodeAt(i);
  return buf.buffer;
}

async function googleAccessToken(): Promise<string> {
  if (!GOOGLE_SERVICE_ACCOUNT_JSON) {
    throw new Error("GOOGLE_SERVICE_ACCOUNT_JSON secret tanımlı değil");
  }
  const creds = JSON.parse(GOOGLE_SERVICE_ACCOUNT_JSON);
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToBinary(creds.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: creds.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: "https://oauth2.googleapis.com/token",
      iat: getNumericDate(0),
      exp: getNumericDate(3600),
    },
    key,
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`google oauth token exchange failed: ${res.status}`);
  }
  const data = await res.json();
  return data.access_token as string;
}

/// `receipt` alanı Play için `PurchaseDetails.verificationData.serverVerificationData`
/// yani satın alma jetonu (purchaseToken)'dır. `productId` abonelik SKU'sudur
/// (rutin_pro_monthly / rutin_pro_yearly).
async function verifyGooglePlaySubscription(
  productId: string,
  purchaseToken: string,
): Promise<boolean> {
  const accessToken = await googleAccessToken();
  const url =
    `https://www.googleapis.com/androidpublisher/v3/applications/` +
    `${GOOGLE_PACKAGE_NAME}/purchases/subscriptions/${productId}/tokens/${purchaseToken}`;

  const res = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return false;

  const data = await res.json();
  // paymentState: 0 = ödeme bekleniyor, 1 = ödendi, 2 = deneme, 3 = gecikmeli ödeme.
  // cancelReason varsa ve süre dolmuşsa geçersiz say.
  const expiryMs = Number(data.expiryTimeMillis ?? 0);
  const notExpired = expiryMs > Date.now();
  const paid = data.paymentState === 1 || data.paymentState === 2;
  return notExpired && paid;
}

/// Tek seferlik ("ömür boyu") ürün — Play'de AYRI bir uç nokta kullanılır.
/// `purchases/subscriptions/...` bu ürün tipinde her zaman 404 döner, bu
/// yüzden eskiden ömür boyu satın alma hiçbir zaman doğrulanamıyordu.
async function verifyGooglePlayProduct(
  productId: string,
  purchaseToken: string,
): Promise<boolean> {
  const accessToken = await googleAccessToken();
  const url =
    `https://www.googleapis.com/androidpublisher/v3/applications/` +
    `${GOOGLE_PACKAGE_NAME}/purchases/products/${productId}/tokens/${purchaseToken}`;

  const res = await fetch(url, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) return false;

  const data = await res.json();
  // purchaseState: 0 = satın alındı, 1 = iptal edildi, 2 = beklemede.
  // Tek seferlik üründe süre kavramı yoktur; sahiplik yeterlidir.
  return data.purchaseState === 0;
}

// ---------------------------------------------------------------------
// Apple App Store — legacy verifyReceipt (production, sandbox fallback)
// ---------------------------------------------------------------------

/// `receipt` alanı App Store için `PurchaseDetails.verificationData.serverVerificationData`
/// yani base64 App Store makbuzudur.
async function verifyAppStoreSubscription(receiptData: string): Promise<boolean> {
  const data = await appleReceipt(receiptData, false);
  if (!data) return false;

  const latest = data.latest_receipt_info as
    | Array<Record<string, unknown>>
    | undefined;
  if (!latest || latest.length === 0) return false;

  // EN GEÇ bitiş tarihini al — dizideki SON elemanı DEĞİL.
  //
  // Apple `latest_receipt_info` dizisinin sıralamasını garanti etmez. Ayrıca
  // ömür boyu ürünü destekleyebilmek için `exclude-old-transactions` artık
  // `false`; yani bu dizi tek bir güncel işlem yerine TÜM abonelik geçmişini
  // içeriyor. Böyle bir dizide `[length - 1]` pekâlâ yıllar önce dolmuş bir
  // işlem olabilir ve geçerli bir abone "süresi dolmuş" sayılırdı. Maksimumu
  // almak sıralamadan ve dizi uzunluğundan bağımsız olarak doğrudur.
  let maxExpiresMs = 0;
  for (const tx of latest) {
    // İade/iptal edilmiş işlemler aboneliği geçerli kılmaz.
    if (tx.cancellation_date_ms) continue;
    const ms = Number(tx.expires_date_ms ?? 0);
    if (Number.isFinite(ms) && ms > maxExpiresMs) maxExpiresMs = ms;
  }
  return maxExpiresMs > Date.now();
}

/// Tek seferlik ("ömür boyu") satın alma — non-consumable.
///
/// Bu ürün tipi `latest_receipt_info`'da GÖRÜNMEZ (orası otomatik yenilenen
/// abonelikler içindir) ve `expires_date_ms` alanı YOKTUR. Eski kod her iki
/// varsayımı da yaptığı için ömür boyu satın alma her zaman `false` dönüyordu.
/// Doğrusu: `receipt.in_app` listesinde ilgili ürünün iptal edilmemiş bir
/// işlemi var mı diye bakmak.
async function verifyAppStoreLifetime(
  receiptData: string,
  productId: string,
): Promise<boolean> {
  const data = await appleReceipt(receiptData, false);
  if (!data) return false;

  const receipt = data.receipt as Record<string, unknown> | undefined;
  const inApp = (receipt?.in_app ?? data.latest_receipt_info) as
    | Array<Record<string, unknown>>
    | undefined;
  if (!inApp || inApp.length === 0) return false;

  return inApp.some((tx) =>
    tx.product_id === productId &&
    // cancellation_date_ms doluysa Apple satın almayı iade/iptal etmiştir.
    !tx.cancellation_date_ms
  );
}

/// Apple'a makbuzu doğrulatır ve ham yanıtı döner (status !== 0 ise null).
async function appleReceipt(
  receiptData: string,
  sandbox: boolean,
): Promise<Record<string, unknown> | null> {
  const url = sandbox
    ? "https://sandbox.itunes.apple.com/verifyReceipt"
    : "https://buy.itunes.apple.com/verifyReceipt";

  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      "receipt-data": receiptData,
      password: APPLE_SHARED_SECRET,
      // Ömür boyu (non-consumable) işlemler `in_app` içinde aranıyor;
      // eski işlemler hariç tutulursa satın alma kaybolabilir.
      "exclude-old-transactions": false,
    }),
  });
  const data = await res.json();

  // 21007: bu makbuz sandbox'ta üretilmiş ama production endpoint'ine
  // gönderilmiş (TestFlight / App Review) → sandbox'a tekrar dene.
  if (data.status === 21007 && !sandbox) {
    return appleReceipt(receiptData, true);
  }
  if (data.status !== 0) return null;
  return data;
}
