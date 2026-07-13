# Rutin — Veri Güvenliği / App Privacy Cevap Taslağı

Hem Google Play "Data Safety" hem Apple "App Privacy" formu, uygulamanın hangi
veriyi topladığını/paylaştığını soruyor. Cevap, **hangi özelliklerin açık
olduğuna** bağlı. Kodda şu an `Ads.init()`, `Social.init()` ve Sentry (boş DSN)
**kapalı**. Bu yüzden iki senaryo hazırladım.

> Önemli ayrım: Play'de "veri toplama" = verinin **cihaz dışına gönderilmesi**.
> Sadece cihazda `shared_preferences` ile saklanan görev/su/streak verisi
> "toplanan veri" SAYILMAZ.

---

## SENARYO A — Minimal Yayın (önerilen ilk sürüm)
Reklam, sosyal katman ve çökme raporlama KAPALI. Tüm veri yalnızca cihazda kalır.

### Google Play — Data Safety
- Does your app collect or share any user data? → **No**
- (Tüm veri cihazda; dışarı gönderilmiyor.)
- Data encrypted in transit? → Uygulanmaz (veri gönderilmiyor)
- Users can request data deletion? → Uygulama içi "Verileri dışa aktar" var;
  silme, uygulamayı kaldırınca gerçekleşir.

### Apple — App Privacy
- Data collection → **Data Not Collected** seç.
- (Nutrition label: "No Data Collected".)

Bu senaryo hem en hızlı onaylanır hem de "No Data Collected / Veri Toplanmıyor"
rozeti güçlü bir güven mesajıdır. İlk sürümü böyle çıkar, ads/social'ı sonraki
güncellemede aç.

---

## SENARYO B — Tam Yayın (Reklam + Sosyal + Çökme raporu açık)
`Ads.init()` (AdMob), `Social.init()` (Supabase arkadaş/liderlik) ve Sentry açık.

### Google Play — Data Safety
Does your app collect or share user data? → **Yes**

| Veri türü | Toplanır | Paylaşılır | Amaç | Zorunlu? |
|---|---|---|---|---|
| Ad / kullanıcı adı (sosyal profil) | Evet | Hayır | Uygulama işlevi (arkadaş/liderlik) | Opsiyonel (sadece sosyal kullanılırsa) |
| Uygulama etkinliği (streak/görev — paylaşılan) | Evet | Hayır | Uygulama işlevi | Opsiyonel |
| Cihaz veya diğer kimlikler (reklam ID) | Evet | Evet (AdMob/Google) | Reklam | Zorunlu (ücretsiz sürüm) |
| Uygulama performansı (çökme günlükleri) | Evet | Hayır | Analiz / hata ayıklama | Opsiyonel |
| Yaklaşık konum (AdMob'un IP tabanlı) | Evet (AdMob) | Evet | Reklam | Zorunlu |

- Data encrypted in transit? → **Evet** (Supabase/AdMob HTTPS)
- Users can request data deletion? → **Evet** (sosyal veri için Supabase'den
  silme; uygulama içi dışa aktarma + kaldırınca yerel silme)

### Apple — App Privacy
- **Data Used to Track You** (ATT gerektirir): Identifiers → Advertising ID
  (AdMob kişiselleştirilmiş reklam açıksa).
- **Data Linked to You**: Contact Info/Name (sosyal profil), User Content
  (paylaşılan streak), Identifiers (reklam ID).
- **Data Not Linked to You**: Diagnostics (çökme), Usage Data.
- Kategoriler: Purchases (IAP — Apple yönetir, sen "linked" seçmezsin),
  Identifiers, Usage Data, Diagnostics, User Content, Contact Info.
- Not: AdMob kullanıyorsan `NSUserTrackingUsageDescription` + ATT izni ŞART,
  aksi halde Advertising ID toplanamaz ve reddedilirsin.

---

## Ortak notlar
- Gizlilik politikası URL'si her iki formda da gerekli: `kprens.github.io/rutin-legal`
  — içinde AdMob, Supabase, (varsa) Sentry ve IAP'den bahsettiğinden emin ol.
- IAP: Ödeme bilgisini uygulama TOPLAMAZ; Apple/Google yönetir. Formda "Financial
  info" işaretlemene gerek yok (mağaza hallediyor).
- Çocuklara yönelik değil → "Target audience" 13+/genel seç; aksi halde ek
  gizlilik yükümlülükleri doğar.

## Öneri
İlk sürümü **Senaryo A** ile çıkar (en hızlı onay + "veri toplanmıyor" güveni).
AdMob ve sosyal katmanı stabilize edip bir sonraki güncellemede açarken formu
**Senaryo B**'ye güncelle.
