# Rutin — Veri Güvenliği / App Privacy Referansı

Bu belge, Google Play "Veri Güvenliği" ve Apple "App Privacy" formlarında
verilen cevapların **gerekçeli kaydıdır**. Her iki form da doldurulmuş
durumda; burası ileride bir özellik eklendiğinde neyin güncellenmesi
gerektiğini gösteren referanstır.

> **Kritik kural:** Formdaki beyan ile kodun yaptığı iş birbirini tutmazsa
> bu bir politika ihlalidir (App Store 5.1.1 / Play Kullanıcı Verileri).
> Cihaz dışına yeni bir veri gönderen her özellik eklendiğinde bu belge ve
> HER İKİ form güncellenmelidir.

---

## 1. Uygulamanın gerçekte topladığı veriler

### Yalnızca cihazda kalanlar

Hesap oluşturulmadıysa bunların hiçbiri cihaz dışına çıkmaz — Play'in
tanımına göre "toplama" sayılmaz.

| Veri | Saklama |
|---|---|
| Alışkanlıklar, günlük işaretlemeler, seriler | `shared_preferences` |
| Bırakma (recovery) kayıtları, nüks sayısı | `shared_preferences` |
| Su takibi, takvim, haftalık program | `shared_preferences` |
| **Kriz/tetikleyici kayıtları** (`triggerLog`) | `shared_preferences` |
| **"Geleceğe Mektup"** (`Streak.letter`) | `shared_preferences` |
| Tema, dil, bildirim tercihleri | `shared_preferences` |

### Hesap oluşturulduğunda sunucuya (Supabase, AB/Frankfurt) gidenler

| Veri | Tablo | Kimler görebilir |
|---|---|---|
| E-posta, kullanıcı adı, arkadaş kodu | `profiles` | Kullanıcı + arkadaşları (yalnızca kullanıcı adı) |
| Tüm uygulama verisi (yukarıdaki listenin tamamı, JSON) | `app_data` | **Yalnızca kullanıcının kendisi** (RLS) |
| Arkadaşlık bağlantıları | `friendships` | İlgili iki kullanıcı |
| Paylaşmayı **seçtiği** streak özetleri | `shared_streaks` | Onaylı arkadaşlar |
| **Panik (destek) sinyalleri** | `panic_signals` | Onaylı arkadaşlar |

⚠️ `app_data` içinde kriz/tetikleyici kayıtları ve mektup da bulunur — ancak
**yalnızca kullanıcının kendi hesabında**, RLS ile korunur; arkadaşlar dahil
kimse göremez.

### Üçüncü taraflara gidenler

| Alıcı | Veri | Amaç |
|---|---|---|
| Google AdMob | Reklam kimliği, yaklaşık konum (IP), reklam etkileşimi | Reklam gösterimi/ölçümü |
| Sentry | Çökme günlüğü, cihaz modeli, OS sürümü | Hata ayıklama |
| Apple / Google Play | Satın alma jetonu | Abonelik doğrulama |

Kart/ödeme bilgisi uygulamaya **hiç ulaşmaz**; mağazalar yönetir.

---

## 2. Google Play — Veri Güvenliği (verilen cevaplar)

Veri toplanıyor mu? → **Evet**

| Veri türü | Toplanır | Paylaşılır | Amaç |
|---|---|---|---|
| Ad | Evet | Hayır | Uygulama işlevi |
| E-posta adresi | Evet | Hayır | Uygulama işlevi (hesap) |
| Kullanıcı kimliği | Evet | Hayır | Uygulama işlevi |
| Diğer kullanıcı içeriği (alışkanlık/bırakma/kriz kayıtları) | Evet | Hayır | Uygulama işlevi |
| Satın alma geçmişi | Evet | Hayır | Uygulama işlevi (Pro) |
| Cihaz veya diğer kimlikler (reklam ID) | Evet | **Evet** (AdMob) | Reklam |
| Uygulama performansı / çökme günlükleri | Evet | Hayır | Analiz, hata ayıklama |

- Aktarımda şifreleme: **Evet** (HTTPS)
- Kullanıcı silme talep edebilir: **Evet** (uygulama içi hesap silme)
- Reklam Kimliği beyanı: **Evet** — manifest'te `AD_ID` izni var
  (Google Mobile Ads SDK'sı otomatik ekliyor)
- Reklam kimliği amacı: yalnızca **Üçüncü Taraf Reklamcılık**

---

## 3. Apple — App Privacy (verilen cevaplar)

**Data Linked to You** — amaç: *App Functionality*
Name, Email Address, User ID, Purchases, Other User Content,
Crash Data, Performance Data

**Data Used to Track You** — amaç: *Third-Party Advertising*
Device ID, Advertising Data
(ATT izni + `NSUserTrackingUsageDescription` Info.plist'te mevcut)

**Beyan EDİLMEYENLER:** Health & Fitness, Financial Info, Location,
Contacts, Photos, Audio, Browsing/Search History, Sensitive Info.

### ⚠️ Gözden geçirilmesi gereken nokta

Kriz/tetikleyici kayıtlarının (bağımlılıkla mücadele bağlamı) Apple'ın
**"Sensitive Info"** tanımına girip girmediği tartışmalıdır. Mevcut beyan
bunları *Other User Content* kapsamında sayıyor. Gerekçeler:

- Veri cihazda kalır; buluta gitse bile yalnızca kullanıcının kendi
  hesabında ve RLS ile korunur
- Reklam veya takip amacıyla **kullanılmaz**, üçüncü tarafla paylaşılmaz
- Tıbbi/klinik veri değildir; HealthKit'e hiç dokunulmaz
- Kullanıcının kendi girdiği serbest içeriktir

Panik sinyali arkadaşlarla paylaşıldığı için de bu kategoride kalmalıdır.
Apple inceleme sırasında soru sorarsa bu gerekçe kullanılabilir. Şüpheye
düşülürse en güvenli yol beyanı genişletmektir (eksik beyan, fazla
beyandan çok daha risklidir).

---

## 4. Yeni özellik eklerken kontrol listesi

Cihaz dışına **yeni bir veri** gidiyorsa:

1. `gizlilik-politikasi.md` güncelle ve yayınla
2. Play Console → Veri Güvenliği formunu güncelle
3. App Store Connect → App Privacy formunu güncelle
4. Bu belgeyi güncelle
5. Yeni bir Supabase tablosuysa **RLS politikalarını yaz** — varsayılan
   olarak açık gelmez, `enable row level security` açıkça gerekir

---

## 5. Ortak notlar

- Gizlilik politikası URL'si (her iki mağazada zorunlu):
  `https://kprens.github.io/rutin-legal`
- IAP: ödeme bilgisi toplanmaz, mağazalar yönetir → "Financial Info"
  işaretlenmez
- Hedef kitle 13+ / genel; çocuklara yönelik değil
- iOS'ta ATT izni olmadan reklam kimliği toplanamaz
