# Rutin — Abonelik & Monetizasyon Stratejisi

> Hazırlayan: Büyüme / Ürün / Fiyatlandırma incelemesi
> Kapsam: Rutin'in mevcut kod tabanı, rakip konumlandırma, 12+ ay abone kalma hedefi

---

## 0. Önce Acı Gerçek: Stratejik Teşhis

Rutin şu anda **yanlış kategoride yarışıyor.**

Kendini "alışkanlık takip uygulaması" olarak konumlandırıyor. Bu kategori:

- Aşırı doymuş (Habitica, Streaks, Loop, Habitify, Done, TickTick…)
- Ödeme isteği düşük — kullanıcı "bunu Notion'da bedavaya yaparım" der
- Duygusal aciliyeti yok — kimse "alışkanlık takip edemiyorum" diye gece 2'de uyanmaz

Ama Rutin'in kodunda çok daha değerli bir ürün saklı: **bırakma / bağımlılıkla mücadele koçu.**

`recovery_screen.dart`, `crisis_screen.dart`, kazanılan para/saat hesabı, nüks (relapse) sayacı, sorumluluk ortağı — bunlar bir alışkanlık takipçisinin özellikleri değil. Bunlar **bir insanın hayatının en zor anına dokunan** özellikler.

Kritik fark:

| | Alışkanlık takipçisi | Bırakma koçu |
|---|---|---|
| Duygusal aciliyet | Düşük | **Çok yüksek** |
| Kullanıcının alternatif maliyeti | Yok | Sigara: aylık 2.000₺+ |
| Ödeme isteği (WTP) | Düşük | **Yüksek** |
| Kriz anı (uygulamayı açma tetiği) | Yok | **Günde defalarca** |
| Rakip yoğunluğu | Aşırı | Orta |

**Tez:** Rutin ücretsiz katmanda cömert bir alışkanlık takipçisi olmalı; Premium ise **"bırakma ve kendine hâkim olma koçu"** olmalı. Para alışkanlıktan değil, bağımlılıktan gelir.

Sigarayı bırakmaya çalışan biri için aylık 149₺, sigaraya harcadığının %7'sidir. Alışkanlık takibi için 149₺ ise "pahalı".

---

## 1. Mevcut Modelin Kritiği (Acımasız)

### 1.1 Ölümcül hatalar

**a) Yıllık plan satılmıyor.**
`iap.dart`'ta `rutin_pro_yearly` tanımlı ve mağazadan çekiliyor, ama `paywall_screen.dart` yalnızca aylık planı gösteriyor. Bu kategoride abonelik gelirinin tipik olarak **%60-75'i yıllık plandan** gelir. Şu anki hâliyle Rutin bu gelirin tamamını kaybediyor. **Tek başına en yüksek etkili düzeltme budur.**

**b) Premium'un vaatleri gerçek değildi.**
Ödeme ekranı "AI İçgörüleri" ve "Akıllı Hatırlatma" vaat ediyordu — bunlar uygulamada yok. "Gelişmiş İstatistik", "Tüm Başarımlar", "Dışa Aktar", "Sınırsız Alışkanlık" ise ücretsizde zaten açıktı. (Bu düzeltildi.) Yanıltıcı vaat = App Store 2.3.1 reddi + iade + 1 yıldız.

**c) Premium'un tek gerçek faydası "reklamsız"dı.**
"Reklamsız" bir *özellik* değil, bir *rahatsızlığın kaldırılması*. Reklamsızlık üzerine kurulu abonelikler düşük fiyat noktasına hapsolur ve LTV'yi öldürür. Kullanıcı 3 ay sonra "zaten reklamlara alıştım" der ve iptal eder.

**d) Değer, kullanıcı değer görmeden önce isteniyor.**
Ödeme ekranı 1. günden erişilebilir. Kullanıcı henüz hiçbir başarı yaşamamışken abonelik istemek dönüşümü düşürür ve güveni zedeler.

### 1.2 Yapısal zayıflık

Ücretsiz katman zaten mükemmel çalışıyor ve bu **doğru**. Sorun ücretsizin cömertliği değil — Premium'un **hiçbir şey vaat etmemesi**.

Doğru soru "neyi kilitleyelim?" değil.
Doğru soru: **"Kullanıcının tek başına asla yapamayacağı hangi işi biz onun yerine yapabiliriz?"**

Cevap: **Kendi davranış verisini yorumlamak.** Kullanıcı 90 günlük nüks kaydına bakıp "cuma akşamları 22:00-01:00 arası risk altındayım" sonucunu çıkaramaz. Biz çıkarabiliriz. İşte satılacak şey bu.

---

## 2. Ücretsiz Plan (Tam Kapsam)

**Felsefe:** Ücretsiz kullanıcı hayatını gerçekten düzeltmeli. Yapay kısıt yok. Ücretsiz katman bizim en büyük pazarlama kanalımızdır — memnun ücretsiz kullanıcı 5 yıldız verir, arkadaşını davet eder, 6 ay sonra abone olur.

| Özellik | Neden ücretsiz? |
|---|---|
| **Sınırsız alışkanlık** | Kısıtlamak temel işlevi sakatlar. Günlük kullanım alışkanlığı = gelecekteki dönüşüm. |
| **Sınırsız günlük işaretleme** | Ürünün kalp atışı. Asla dokunulmaz. |
| **Sınırsız hatırlatma** | Hatırlatma = uygulamaya geri dönüş = retention. Kısıtlamak kendi ayağımıza sıkmaktır. |
| **Sınırsız bırakma takibi** ⚠️ *(değişiklik)* | Aşağıda açıklanıyor. Mevcut 2'lik limit kaldırılmalı. |
| **Seri (streak) takibi** | Temel motivasyon mekaniği. |
| **Kazanılan para/saat sayacı** | En güçlü "aha" anı. Bunu ücretsiz vermek dönüşümü *artırır* — kullanıcı değerin somut olduğunu görür. |
| **Su takibi** | Yan özellik, ödeme gerekçesi değil. |
| **Takvim & haftalık program** | Kullanım sıklığını artırır. |
| **Temel istatistikler (7/30 gün)** | Merak yaratır, derin analiz iştahı açar. |
| **Başarımlar & rozetler** | Ücretsiz dopamin. Retention motoru. |
| **2 ücretsiz tema** | Kişiselleştirmenin tadı; gerisi Premium. |
| **Sorumluluk ortağı (1 kişi)** | Viral döngü. Kısıtlamak büyümeyi öldürür. |
| **Kriz/SOS ekranı (temel)** | **Etik zorunluluk.** Krizdeki insanın önüne ödeme duvarı koymak affedilemez. Ayrıca en güçlü güven kaynağı. |
| **Veri dışa aktarma** | Kullanıcı verisi kullanıcınındır. Kilitlemek güven kırar (ve AB'de sorun yaratır). |

### ⚠️ Öneri: Bırakma takibindeki 2'lik limiti KALDIR

Mevcut `freeStreakLimit = 2` yanlış bir kısıt. Gerekçe:

1. Bağımlılıklar kümelenir — sigarayı bırakan kişi genelde aynı anda alkolü ve şekeri de bırakmaya çalışır. Üçüncüsünde duvar görmek, tam da en kırılgan anında cezalandırılmak demektir.
2. Bu, "sayı kısıtı" tipi bir kısıt — kullanıcının talimatında açıkça istenmeyen tür.
3. Kaldırıldığında kaybedilen gelir minimal; kazanılan güven ve retention çok daha değerli.

Bunun yerine satılacak olan şey **sayı değil, zekâ**: kaç tane takip ettiğin ücretsiz, o takiplerin *ne anlama geldiği* Premium.

---

## 3. Premium Plan — "Rutin Coach"

**Konumlandırma cümlesi:**
> "Rutin ücretsiz seni takip eder. Rutin Coach seni tanır."

Premium bir özellik listesi değil, bir **kişisel başarı sistemi** olarak paketlenmeli. İsim önerisi: **Rutin Coach** (Pro değil — "Pro" jenerik ve işlevsel; "Coach" duygusal ve ilişkiseldir).

### 3.1 Premium'un dört sütunu

**Sütun 1 — Beni Tanı (Kişisel Zekâ)**
Davranış verimi benim adıma yorumla.

**Sütun 2 — Beni Koru (Öngörü & Kriz)**
Ben düşmeden önce müdahale et.

**Sütun 3 — Bana Yol Göster (Koçluk)**
Ne yapacağımı söyle, sadece veri gösterme.

**Sütun 4 — Beni Sorumlu Tut (Sosyal)**
Yalnız bırakma.

---

## 4. Orijinal "Killer" Premium Özellikler

Aşağıdaki 10 özellik hiçbir alışkanlık takipçisinde bu biçimde yok. Her biri Rutin'in mevcut verisiyle (nüks kayıtları, işaretleme zamanları, takvim, seri geçmişi) çalışır — yani rakiplerin kopyalaması için **önce bizim kadar veri toplamaları gerekir.** Moat budur.

---

### ⭐ 1. Risk Penceresi Tahmini (Relapse Radar)

**Ne yapar:** Geçmiş nüks ve kaçırılan işaretleme kayıtlarından kişisel risk desenini çıkarır. "Son 3 nüksünün 2'si cuma 22:00–01:00 arasında oldu. Bu akşam yüksek risk. Planın ne?" bildirimi gönderir — **nüks olmadan önce.**

**Neden ödenir:** Kullanıcı bir daha düşmemek için para verir. Bu, ürünün tamamındaki en yüksek duygusal değerli vaat.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 10 | Doğrudan en büyük korkuya hitap ediyor: "yine başaramayacağım". |
| Günlük faydalılık | 8 | Her gün değil ama her riskli günde — ki o günler en kritik olanlar. |
| Duygusal etki | 10 | "Uygulama beni benden iyi tanıyor" hissi. |
| Algılanan değer | 10 | Bir insan koçunun yapacağı iş. |
| Retention etkisi | 10 | Bildirimi alan kullanıcı geri döner; işe yaradığında asla iptal etmez. |
| Gelir potansiyeli | 10 | Tek başına aboneliği haklı çıkarır. |
| Geliştirme karmaşıklığı | 4 (kolay) | AI gerekmez — basit zaman/gün frekans analizi yeterli. Veri zaten var. |
| AI farklılaşması | 7 | İstatistiksel; AI ile daha da güçlenir. |
| Rekabet avantajı | 9 | Rakiplerde nüks zaman damgası verisi yok. |

**Hangi acıyı çözer:** Kontrol kaybı korkusu.
**Kullanım sıklığı:** Haftada 1–3 proaktif temas.
**Tekrarlayan değer:** Evet — model her nüksle keskinleşir.
**Değiştirme maliyeti (switching cost):** Çok yüksek — model kullanıcının kendi geçmişi üzerine kurulu, başka uygulamaya taşınamaz.

**Benzer strateji kullananlar:** Rise Sleep (uyku borcu tahmini), Whoop (toparlanma skoru).
**Psikolojik temel:** İnsanlar kayıptan kaçınmayı (loss aversion) kazanç arayışına tercih eder. "Serini kaybetme" > "yeni seri kur".
**Bizim üstünlüğümüz:** Whoop donanım ister; biz davranışsal veriyle aynı hissi yaratıyoruz.

---

### ⭐ 2. Kriz Anı Koçu (SOS Coach)

**Ne yapar:** Kriz ekranı ücretsizde temel kalır (etik zorunluluk). Premium'da ise kriz anı **kişiselleştirilir**: kullanıcının daha önce hangi tekniğin işe yaradığını hatırlar ("Geçen sefer yürüyüş seni kurtarmıştı"), o ana özel nefes/dikkat dağıtma protokolü sunar, kriz atlatıldıktan sonra "ne tetikledi?" mikro-anketiyle veriyi zenginleştirir.

**Neden ödenir:** İnsanın en çaresiz anında yanında olan şeye para verilir.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 10 | Ürünün duygusal zirvesi. |
| Günlük faydalılık | 7 | Kriz sıklığına bağlı; ilk haftalarda çok yüksek. |
| Duygusal etki | 10 | Uygulamayla kurulan bağın en güçlü anı. |
| Algılanan değer | 10 | Terapi/koçluk çağrışımı. |
| Retention etkisi | 10 | Bir kez "beni kurtardı" diyen kullanıcı yıllarca kalır. |
| Gelir potansiyeli | 9 | |
| Geliştirme karmaşıklığı | 5 | Mevcut kriz ekranı üzerine kurulabilir. |
| AI farklılaşması | 8 | Kişiselleştirme AI ile derinleşir. |
| Rekabet avantajı | 9 | Kriz verisi biriktirmek zaman ister. |

**Kritik etik not:** Ücretsiz kullanıcının kriz ekranı asla kısıtlanmamalı, hiçbir ödeme duvarı gösterilmemeli. Kriz anında satış yapmak hem etik dışıdır hem marka intiharıdır.

---

### ⭐ 3. Geleceğe Mektup (Time Capsule)

**Ne yapar:** Kullanıcı bırakmaya başladığı gün, en kararlı anında kendine bir mesaj (metin veya sesli) bırakır: *"Neden bırakıyorum."* Uygulama bu mesajı **kriz anında ve nüks riski yüksek olduğunda** kullanıcıya geri oynatır.

**Neden ödenir:** Bu, hiçbir rakipte olmayan, kopyalanması teknik olarak kolay ama duygusal olarak imkânsız bir özellik — çünkü değeri **kullanıcının kendi sesinden** gelir.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 9 | Anlatması kolay, duygusal olarak çarpıcı. |
| Günlük faydalılık | 5 | Nadir ama yüksek yoğunluklu kullanım. |
| Duygusal etki | 10 | Ürünün tamamındaki en güçlü an olabilir. |
| Algılanan değer | 9 | |
| Retention etkisi | 9 | Kayıp korkusu: mektup uygulamada yaşıyor. |
| Gelir potansiyeli | 8 | |
| Geliştirme karmaşıklığı | 3 (çok kolay) | Ses kaydı + oynatma. |
| AI farklılaşması | 2 | AI gerekmiyor — ve gerekmemesi bir avantaj (maliyet yok). |
| Rekabet avantajı | 10 | Kopyalanabilir ama **taşınamaz** — kullanıcının kendi kaydı burada. |

**Psikolojik temel:** Commitment & consistency (Cialdini) + kendi sesini duymanın öz-ikna gücü.
**Bizim üstünlüğümüz:** Hiçbir alışkanlık uygulamasında yok. Ekran görüntüsü paylaşılabilir, organik büyüme yaratır.

---

### ⭐ 4. Haftalık Hayat Raporu

**Ne yapar:** Her pazar sabahı kişiselleştirilmiş bir rapor: bu hafta ne kazandın (para, saat, temiz gün), hangi gün zorlandın, hangi alışkanlık seni ileri taşıdı, gelecek hafta için tek bir odak önerisi.

**Neden ödenir:** Tekrarlayan değerin klasik motoru. Her hafta yeni bir "açılacak hediye".

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 8 | Somut, öngörülebilir teslimat. |
| Günlük faydalılık | 6 | Haftalık ama beklenen bir ritüel. |
| Duygusal etki | 8 | İlerlemeyi görünür kılar. |
| Algılanan değer | 8 | |
| Retention etkisi | 10 | **Abonelik iptallerini en çok geciktiren mekanizma:** "Pazar raporumu kaçırırım." |
| Gelir potansiyeli | 8 | |
| Geliştirme karmaşıklığı | 4 | Veri zaten var. |
| AI farklılaşması | 7 | Metin üretimi AI ile daha insansı. |
| Rekabet avantajı | 6 | Kopyalanabilir — ama veri derinliği bizde. |

**Benzer strateji:** Spotify Wrapped, Whoop Weekly, Rise. **Neden işe yarar:** Zeigarnik etkisi + öngörülebilir ödül döngüsü.

---

### ⭐ 5. Tetikleyici Haritası (Trigger Map)

**Ne yapar:** Nüks ve kriz anlarında sorulan mikro-anketlerden (tek dokunuş: stres / can sıkıntısı / sosyal ortam / yorgunluk / öfke) kişisel tetikleyici haritası oluşturur: "Nükslerinin %64'ü *stres* etiketli. Stres anında en çok işe yarayan tekniğin: 10 dakika yürüyüş."

**Neden ödenir:** Kullanıcı kendisi hakkında asla ulaşamayacağı bir içgörü alıyor.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 9 | "Kendini tanı" vaadi çok güçlü. |
| Günlük faydalılık | 6 | |
| Duygusal etki | 9 | Kendini anlaşılmış hissetme. |
| Algılanan değer | 9 | Terapide haftalarca sürecek iş. |
| Retention etkisi | 9 | Veri biriktikçe değer artar → ayrılmak zorlaşır. |
| Gelir potansiyeli | 9 | |
| Geliştirme karmaşıklığı | 5 | Mikro-anket + toplama. |
| AI farklılaşması | 6 | |
| Rekabet avantajı | 9 | Veri seti bizde birikiyor. |

---

### ⭐ 6. Sağlık Geri Kazanım Zaman Çizelgesi

**Ne yapar:** Bırakılan maddeye özel, kanıta dayalı iyileşme kilometre taşları: sigara için "20 dakika: nabzın normale döndü → 72 saat: nikotin vücudundan tamamen çıktı → 2 hafta: akciğer kapasiten %30 arttı → 1 yıl: kalp krizi riskin yarıya indi". Her kilometre taşı ulaşıldığında kutlama bildirimi.

**Neden ödenir:** Bırakma uygulamalarında en çok paylaşılan ekran budur. Somut, bilimsel, motive edici.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 9 | Ölçülebilir sağlık kazanımı = ikna edici. |
| Günlük faydalılık | 7 | Erken dönemde çok sık kontrol edilir. |
| Duygusal etki | 9 | Umut üretir. |
| Algılanan değer | 9 | |
| Retention etkisi | 10 | **Bir sonraki kilometre taşı hep önde** → ayrılma maliyeti. |
| Gelir potansiyeli | 9 | |
| Geliştirme karmaşıklığı | 3 | Statik içerik + tarih hesabı. AI yok, maliyet yok. |
| AI farklılaşması | 1 | Gerekmiyor. |
| Rekabet avantajı | 5 | Quit-app'lerde var, habit tracker'larda yok. |

⚠️ **Uyum notu:** Tıbbi iddia dili dikkatli kullanılmalı ("genel araştırmalara göre", kaynak belirtilmeli). Tanı/tedavi iddiası kesinlikle olmamalı — App Store sağlık politikası riski.

---

### ⭐ 7. Ortak Sorumluluk Sözleşmesi (Pact)

**Ne yapar:** İki kullanıcı karşılıklı bir "sözleşme" imzalar: hedef, süre, ve bozulursa ne olacağı (ör. karşı tarafa özür mesajı otomatik gider). Panik butonu: kriz anında ortağına anında bildirim gider — "şu an zorlanıyorum".

**Neden ödenir:** Sosyal baskı, kendi disiplininden çok daha güçlüdür. Ayrıca **her Premium kullanıcı bir kişiyi daha uygulamaya davet eder** — CAC'ı düşürür.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 9 | |
| Günlük faydalılık | 8 | |
| Duygusal etki | 9 | Yalnız olmama hissi. |
| Algılanan değer | 8 | |
| Retention etkisi | 10 | **Sosyal bağ = en yüksek switching cost.** Ortağın orada olduğu için gidemezsin. |
| Gelir potansiyeli | 10 | Viral: davet edilen kişi de dönüşür. |
| Geliştirme karmaşıklığı | 6 | Arkadaş altyapısı mevcut. |
| AI farklılaşması | 2 | |
| Rekabet avantajı | 8 | Ağ etkisi — kopyalanan özellik değil, kopyalanamayan ağ. |

---

### ⭐ 8. Seri Sigortası (Streak Insurance) — dikkatli tasarım

**Ne yapar:** Ayda 1 "donma" hakkı: hastalık, seyahat veya gerçek bir engel yaşandığında seri kırılmaz. Premium kullanıcı ayda 2 hak alır.

**Neden ödenir:** Kayıp korkusu en güçlü satın alma motorudur.

⚠️ **Karanlık desen uyarısı:** Bu özellik kolayca sömürüye dönüşebilir. Kural: **ücretsiz kullanıcıya da ayda 1 hak verilmeli.** "Serini kaybettin, kurtarmak için öde" ekranı **asla** gösterilmemeli — bu klasik bir dark pattern'dır ve uzun vadede güveni yok eder.

| Kriter | Puan |
|---|---|
| Abonelik cazibesi | 7 |
| Retention etkisi | 9 |
| Geliştirme karmaşıklığı | 2 |
| Etik risk | ⚠️ Yüksek — dikkatli uygulanmalı |

---

### ⭐ 9. "Bu Sana Özel" Adaptif Zorluk

**Ne yapar:** Uygulama kullanıcının başarı oranını izler. Sürekli başaramadığı bir alışkanlığı fark ederse **hedefi kendiliğinden küçültmeyi önerir**: "Her gün 30 dk spor 3 haftadır tutmuyor. 10 dakikaya indirelim mi? Küçük ama tuttuğun bir hedef, büyük ama tutmadığından iyidir."

**Neden ödenir:** Uygulamanın kullanıcıyı yargılamak yerine **onun tarafında** olduğunu hissettiren nadir bir an.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Abonelik cazibesi | 8 | |
| Duygusal etki | 10 | Suçluluk yerine şefkat — kategoride çok nadir. |
| Retention etkisi | 10 | **Terk etme sebebinin ta kendisini çözer:** insanlar başaramadıkları için uygulamayı silerler. |
| Geliştirme karmaşıklığı | 4 | |
| Rekabet avantajı | 8 | Rakipler ceza mekaniği kurar, biz uyarlanma kurarız. |

**Bu özellik, kategorideki en büyük terk sebebini (başarısızlık utancı) doğrudan hedef alır. Stratejik olarak en değerli maddelerden biri.**

---

### ⭐ 10. Yıllık Dönüşüm Raporu (Rutin Wrapped)

**Ne yapar:** Yılda bir, paylaşılabilir görsel özet: toplam temiz gün, kazanılan para, geri kazanılan saat, en uzun seri, atlatılan kriz sayısı.

**Neden ödenir:** Doğrudan ödenmez — ama **yıllık aboneliği yenileten duygusal çıpa** budur ve organik büyümenin motorudur.

| Kriter | Puan | Gerekçe |
|---|---|---|
| Organik büyüme | 10 | Sosyal medyada paylaşılır (Spotify Wrapped etkisi). |
| Yenileme etkisi | 10 | Yıllık aboneliğin bitimine denk getirilir. |
| Geliştirme karmaşıklığı | 4 | |

---

### Elenen fikirler (acımasız öz-eleştiri)

| Fikir | Neden elendi |
|---|---|
| **AI sohbet mentoru** | 2026'da herkesin cebinde ChatGPT var. Farklılaşma sıfır, API maliyeti sürekli, marj katili. Ayrıca hassas konularda (bağımlılık) sorumluluk riski çok yüksek. |
| **Takvim optimizasyonu / akıllı planlama** | Rutin bir takvim uygulaması değil. Odağı dağıtır, Sunsama/Motion ile yarışamaz. |
| **Burnout tespiti** | Kulağa hoş geliyor ama Rutin'de bunu ölçecek veri yok (uyku, kalp atışı, ekran süresi). Veri olmadan yapılırsa sahte olur — güven kırar. |
| **Sınırsız alışkanlık (Premium)** | Ücretsizde zaten sınırsız olmalı. Sahte kısıt. |
| **Gelişmiş istatistik (tek başına)** | Ham grafik satmaz. Grafiğin *yorumu* satar (bkz. Tetikleyici Haritası). |
| **Bulut yedekleme** | 2026'da kullanıcı bunu temel bir hak sayar, özellik saymaz. |

---

## 5. Özellik Yerleşim Analizi

| Özellik | Katman | Dönüşüm | Retention | Memnuniyet | Gelir | Algılanan değer |
|---|---|---|---|---|---|---|
| Sınırsız alışkanlık | Ücretsiz | — | ↑↑↑ | ↑↑↑ | — | Orta |
| Sınırsız bırakma takibi | Ücretsiz *(değişiklik)* | ↑ | ↑↑↑ | ↑↑↑ | — | Yüksek |
| Temel kriz ekranı | Ücretsiz | ↑↑ | ↑↑↑ | ↑↑↑ | — | Çok yüksek |
| Para/saat sayacı | Ücretsiz | ↑↑ | ↑↑ | ↑↑↑ | — | Yüksek |
| Sorumluluk ortağı (1) | Ücretsiz | ↑↑↑ | ↑↑↑ | ↑↑ | ↑ | Yüksek |
| **Risk Penceresi Tahmini** | **Premium** | ↑↑↑ | ↑↑↑ | ↑↑ | ↑↑↑ | Çok yüksek |
| **Kriz Koçu (kişisel)** | **Premium** | ↑↑↑ | ↑↑↑ | ↑↑↑ | ↑↑↑ | Çok yüksek |
| **Geleceğe Mektup** | **Premium** | ↑↑ | ↑↑↑ | ↑↑↑ | ↑↑ | Çok yüksek |
| **Haftalık Rapor** | **Premium** | ↑↑ | ↑↑↑ | ↑↑ | ↑↑ | Yüksek |
| **Tetikleyici Haritası** | **Premium** | ↑↑↑ | ↑↑↑ | ↑↑ | ↑↑↑ | Çok yüksek |
| **Sağlık Zaman Çizelgesi** | **Premium** | ↑↑ | ↑↑↑ | ↑↑↑ | ↑↑ | Yüksek |
| **Ortak Sözleşme + Panik** | **Premium** | ↑↑ | ↑↑↑ | ↑↑ | ↑↑↑ | Yüksek |
| **Adaptif Zorluk** | **Premium** | ↑↑ | ↑↑↑ | ↑↑↑ | ↑↑ | Yüksek |
| Tüm temalar | Premium | ↑ | ↑ | ↑ | ↑ | Düşük |
| Reklamsız | Premium (yan fayda) | ↑ | ↑ | ↑↑ | ↑ | Düşük |

**Kritik ilke:** Reklamsızlık ve temalar artık *baş vaat* değil, *ek fayda* olarak konumlanmalı. Baş vaat: **"Bir daha yalnız mücadele etme."**

---

## 6. Kullanıcı Abonelik Yolculuğu

### 1. Gün — "Bir şans daha veriyorum"
- **Zihin durumu:** Şüpheci, daha önce 3 uygulama denedi ve bıraktı.
- **Duygu:** Umut + utanç karışımı.
- **Alınan değer:** 60 saniyede kurulum; ilk bırakma hedefini girer; **anında** "bu yıl 24.000₺ ve 340 saat kazanacaksın" projeksiyonunu görür.
- **Keşfedilen özellik:** Sayaç, ilk işaretleme.
- **Güven:** Ödeme duvarı görmedi → güven +.
- **Yükseltme motivasyonu:** SIFIR. **Bu aşamada abonelik önerilmez.** (Mevcut ürünün en büyük hatası.)

### 3. Gün — "İşe yarıyor olabilir"
- **Duygu:** Kırılgan gurur. İlk gerçek kriz muhtemelen yaşandı.
- **Değer:** Kriz ekranını kullandı, atlattı.
- **Tetik:** Kriz atlatıldıktan **sonra** (asla sırasında): *"Bunu atlattın. Bu anı hatırla — kendine bir mesaj bırakmak ister misin?"* → Geleceğe Mektup tanıtımı.
- **Yükseltme motivasyonu:** Düşük-orta. İlk yumuşak temas.

### 7. Gün — "Bir haftadır dayanıyorum"
- **Duygu:** Gerçek gurur. İlk kimlik değişimi sinyali ("ben bırakan biriyim").
- **Değer:** İlk sağlık kilometre taşı bildirimi (ücretsiz olarak 1 tanesi gösterilir).
- **Tetik:** *"İlk haftalık raporun hazır"* → rapor **bir kez ücretsiz gösterilir.** Değeri yaşat, sonra sat.
- **Yükseltme motivasyonu:** **Orta-yüksek. İlk gerçek dönüşüm penceresi.**

### 14. Gün — "Bunu sürdürebilirim"
- **Duygu:** Güven artıyor ama ilk gevşeme riski başlıyor.
- **Değer:** Yeterli veri birikti → ilk desen tespiti mümkün.
- **Tetik:** *"Verinde bir desen fark ettik. 3 zorlanmanın da aynı saat aralığında olduğunu biliyor muydun?"* — desenin **varlığı** gösterilir, **içeriği** Premium.
- **Yükseltme motivasyonu:** **Yüksek. Merak boşluğu (curiosity gap) en güçlü tetikleyici.**

### 30. Gün — "Bu artık benim kimliğim"
- **Duygu:** Sahiplenme. Uygulamada birikmiş 30 günlük veri var → kayıp korkusu oluştu.
- **Değer:** Aylık dönüşüm özeti, ilk büyük kilometre taşı kutlaması.
- **Tetik:** Yıllık plan indirimi ilk kez burada sunulur — çünkü kullanıcı artık uzun vadeli düşünüyor.
- **Yükseltme motivasyonu:** **Çok yüksek. Yıllık plan için en verimli an.**

### 60. Gün — "Zor kısım şimdi"
- **Duygu:** Motivasyon platosu. Terk riski zirvede.
- **Değer:** Adaptif zorluk devreye girer; uygulama hedefi küçültmeyi önerir → kullanıcı yargılanmadığını hisseder.
- **Tetik:** *"İki aydır buradasın. Çoğu insan burada bırakır — sen bırakmadın."*
- **Yükseltme motivasyonu:** Orta (çoğu zaten dönüşmüş olmalı); dönüşmeyen için ikinci pencere.

### 90. Gün — "Değiştim"
- **Duygu:** Kalıcı kimlik değişimi. Uygulama hayat hikâyesinin parçası.
- **Değer:** 90 günlük derin analiz raporu; sorumluluk ortağıyla kurulmuş bağ.
- **Güven:** Maksimum. Bu kullanıcı artık **savunucu (advocate)** — arkadaş davet eder, 5 yıldız verir.
- **Yükseltme motivasyonu:** Yıllık plana geçiş / yenileme.

---

## 7. 25+ Doğal Yükseltme Tetikleyicisi

**İlke:** Her tetikleyici bir *kazanım anına* veya *merak boşluğuna* bağlanır. Hiçbiri kullanıcıyı engellemez, korkutmaz veya kriz anında rahatsız etmez.

**Başarı anları (en yüksek dönüşüm)**
1. İlk hafta tamamlandı → "İlk haftalık raporun hazır"
2. İlk kriz atlatıldı → "Bu anı kaydet: Geleceğe Mektup"
3. İlk sağlık kilometre taşına ulaşıldı → "Sıradaki 6 kilometre taşını gör"
4. 7 günlük seri → "Serini koruyan desenleri öğren"
5. 30 günlük seri → "30 günlük dönüşüm raporun hazır"
6. Kazanılan para 1.000₺'yi geçti → "Bu parayla ne yapacaksın? Hedef koy"
7. Kusursuz hafta (tüm görevler) → "Bunu tekrarlamanın formülünü çıkardık"
8. İlk arkadaş eklendi → "Sözleşme yapın, birlikte daha güçlüsünüz"

**Merak boşluğu (curiosity gap)**
9. "Verinde bir desen bulduk" (içerik kilitli)
10. "En riskli saatin belli oldu"
11. "En güçlü olduğun gün hangisi, biliyor musun?"
12. "3 tetikleyicinden 1'i baskın çıktı"
13. "Bu ay geçen aya göre %X daha iyisin — nedenini biliyoruz"
14. "Başarı olasılığın hesaplandı"

**Öngörü / koruma**
15. "Bu akşam yüksek risk penceresi" (uyarının varlığı ücretsiz, detayı Premium)
16. "Geçen yıl bu hafta zorlanmıştın"
17. "Serin risk altında — koruma planın hazır"
18. "Tatil/seyahat modu: rutinini koruma stratejisi"

**Zorlanma anları (şefkatle)**
19. Nüks sonrası → "Yeniden başlamak zayıflık değil. Bu sefer neyi farklı yapacağımızı planlayalım"
20. 3 gün üst üste kaçırıldı → "Hedefin sana çok mu büyük geldi? Birlikte küçültelim"
21. Uygulama 5 gün açılmadı → "Sensiz de sayaç işledi. 12 gün temizsin."

**Sosyal**
22. Arkadaş Premium aldı → "X seninle sözleşme yapmak istiyor"
23. Arkadaş kriz atlattı → "Ortağın bugün zorlandı ve başardı"
24. Arkadaşın seni geçti → "Ortağın 20 günde, sen 14'tesin"

**Zamanlama / dönemsel**
25. Ay sonu → "Aylık raporun hazırlanıyor"
26. Yıl sonu → "Rutin Wrapped'in hazır"
27. Kullanıcının bırakma yıldönümü → "1 yıl oldu"
28. Ödüllü reklamla 4 saatlik Pro denemesi bitti → "Beğendin mi? Kalıcı hale getir" *(mevcut mekanizma — güçlü bir sampler)*

---

## 8. Fiyatlandırma Stratejisi

### 8.1 Mevcut durumun sorunu
- Yalnızca aylık $4.99 satılıyor, **yıllık plan satın alınamıyor** (kod hatası).
- $4.99 "alışkanlık takipçisi" fiyatıdır — "bırakma koçu" fiyatı değil.

### 8.2 Önerilen yapı

| Plan | Fiyat (TR) | Fiyat (Global) | Rol |
|---|---|---|---|
| Aylık | 149₺ | $6.99 | **Çıpa** — pahalı görünmesi kasıtlı |
| **Yıllık** | **749₺** (≈62₺/ay) | **$39.99** | **Ana ürün** — %58 tasarruf vurgusu |
| Ömür boyu | 1.499₺ | $79.99 | Şüphecileri ve abonelik yorgunlarını yakalar |

**Neden bu yapı:**
- Aylık fiyatı yüksek tutmak yıllık planı ucuz gösterir (anchoring). Yıllığın tek başına fiyatı değil, **aylığa göre görünen indirimi** satar.
- Ömür boyu seçeneği, "abonelik istemiyorum" diyen segmenti kurtarır — bu kitle bırakma uygulamalarında sanılandan büyüktür ve **peşin nakit akışı** sağlar (bir indie geliştirici için kritik).
- Türkiye fiyatı satın alma gücüne göre ayrı belirlenmeli; global fiyatla aynı olmamalı.

### 8.3 Deneme (trial) stratejisi
- **7 gün ücretsiz deneme, yalnızca yıllık planda.** Aylıkta deneme sunma — deneme maliyetini en yüksek LTV'li plana yönlendir.
- Deneme bitiminden 2 gün önce hatırlatma bildirimi (Apple zaten gönderir; biz kendi değer özetimizi de göndermeliyiz: *"Denemende 9 gün temiz kaldın, 640₺ kazandın"*).

### 8.4 Yükseltme zamanlaması
- Gün 1–6: **abonelik teklifi yok.** (Sadece ayarlar içinden erişilebilir.)
- Gün 7: ilk yumuşak teklif (haftalık rapor sonrası).
- Gün 14: merak boşluğu teklifi (desen tespiti).
- Gün 30: yıllık plan + indirim.
- Nüks sonrası: **asla teklif gösterme** (7 gün sessizlik). Bu, güvenin sınandığı andır.

### 8.5 Reklam stratejisiyle uyum
Mevcut ödüllü reklam → 4 saatlik Pro denemesi mekanizması **korunmalı ve öne çıkarılmalı.** Bu, sektörde "değeri tattırma" (sampling) olarak bilinen en etkili dönüşüm araçlarından biridir. Ölçülmesi gereken: ödüllü reklam izleyenlerin abonelik dönüşüm oranı vs. izlemeyenler.

---

## 9. Rekabetçi Konumlandırma

| Rakip | Güçlü yanı | Bizim üstünlüğümüz |
|---|---|---|
| Streaks / Habitify | Sadelik, tasarım | Onlar sadece takip eder; biz **yorumlarız ve müdahale ederiz** |
| Habitica | Oyunlaştırma | Oyun mekaniği yetişkin bağımlılık mücadelesinde inandırıcı değil |
| QuitNow / Nomo | Bırakma odağı, topluluk | Onlarda alışkanlık/rutin katmanı ve öngörü yok |
| Fabulous | Koçluk hissi, içerik | Onlarınki genel içerik; bizimki **kişinin kendi verisinden** üretiliyor |
| Calm / Headspace | Marka, içerik kütüphanesi | Farklı kategori; biz davranış, onlar zihin |

**Boşluk:** "Bırakma odaklı + öngörülü + sosyal sorumluluk" üçlüsünü birleştiren kimse yok. Rutin'in konumu tam burası olmalı.

**Tek cümlelik konumlandırma:**
> *"Rutin, bırakmaya çalıştığın şeyi bırakmana yardım eden ilk uygulama — çünkü sen düşmeden önce fark eder."*

---

## 10. Acımasız Öz-Eleştiri

**Bu planın zayıf noktaları:**

1. **Uygulama kapasitesi riski.** Burada önerilen 10 özellik, tek kişilik bir ekip için 6–12 aylık iş. Hepsini birden yapmaya çalışmak, hiçbirini iyi yapmamak demektir. → **Çözüm: aşağıdaki 3 fazlı yol haritası.**

2. **Veri kıtlığı sorunu.** Risk tahmini ve tetikleyici haritası, kullanıcının en az 3–4 hafta veri biriktirmesini gerektirir. İlk 30 günde bu özellikler boş görünür. → **Çözüm:** Erken dönemde Sağlık Zaman Çizelgesi ve Geleceğe Mektup gibi **veri gerektirmeyen** Premium özellikler öne çıkarılmalı.

3. **AI maliyeti marjı yiyebilir.** 149₺/ay fiyatla yoğun AI kullanımı marjı eritir. → **Çözüm:** Önerilen özelliklerin çoğu (risk penceresi, tetikleyici haritası, sağlık çizelgesi, mektup) **AI gerektirmiyor** — istatistik ve şablon yeterli. AI yalnızca haftalık rapor metnini insanileştirmek için, düşük maliyetli modelle kullanılmalı.

4. **Sağlık iddiası politika riski.** Sağlık zaman çizelgesi ve bağımlılık dili, App Store/Play sağlık politikalarını tetikleyebilir. → **Çözüm:** Tıbbi tavsiye değil bilgilendirme dili, kaynak gösterimi, "profesyonel destek almayı düşünün" yönlendirmesi.

5. **Etik risk — en önemlisi.** Bağımlılıkla mücadele eden insanların en kırılgan anlarını monetize ediyoruz. Kriz anında satış yapmak, nüks sonrası ödeme duvarı göstermek, "serini kurtarmak için öde" demek — bunların hepsi hem etik dışıdır hem uzun vadede markayı yok eder. **Bu kırmızı çizgiler kod seviyesinde korunmalı, pazarlama insafına bırakılmamalı.**

6. **Sınırsız bırakma takibi önerisi geliri düşürür mü?** Kısa vadede evet, marjinal olarak. Uzun vadede hayır — çünkü mevcut limit zaten çok az gelir üretiyor (kaç kullanıcı 3. bağımlılığı için ödeme yapar?) ama çok fazla hayal kırıklığı üretiyor.

---

## 11. Yönetici Özeti ve Yol Haritası

### Stratejik karar
Rutin, alışkanlık takipçisi kategorisinden çıkıp **"bırakma ve öz-kontrol koçu"** kategorisine konumlanmalıdır. Ücretsiz katman cömert kalmalı; Premium, kullanıcının kendi davranış verisinin **yorumlanması ve öngörüye çevrilmesi** üzerine kurulmalıdır.

### Faz 1 — Bu ay (gelir sızıntısını kapat) ✅ KOD TARAFI TAMAMLANDI
> *Yeni özellik yok. Sadece mevcut değeri satılabilir hale getir.*

1. ✅ **Yıllık planı ödeme ekranına ekle.** Plan seçici eklendi; yıllık
   varsayılan seçili, "EN AVANTAJLI" rozetli ve tasarruf yüzdesi mağazadan
   gelen gerçek fiyatlardan hesaplanıyor.
2. ✅ Ömür boyu seçeneği (`rutin_pro_lifetime`) eklendi — mağazada tanımlı
   değilse otomatik gizleniyor.
3. ⏳ Fiyatları yeniden konumlandır — **mağaza tarafı, elle yapılacak** (bkz. §8.2).
4. ✅ Ödeme ekranı başlığı "dönüşüm vaadi"ne çevrildi; özellik listesi
   yalnızca gerçekten kilitli olanları gösteriyor.
5. ✅ Premium tanıtım kartları 7. güne taşındı (`AppState.showPremiumPromos`).
   Ödeme ekranının kendisi her zaman erişilebilir.
6. ✅ Bırakma takibindeki 2'lik limit tamamen kaldırıldı.

**Kalan elle yapılacak işler:**
- App Store Connect + Play Console'da `rutin_pro_yearly` ürününü oluştur/etkinleştir
- `rutin_pro_lifetime` ürününü oluştur (App Store: Non-Consumable, Play: tek seferlik ürün)
- 7 günlük ücretsiz denemeyi **yalnızca yıllık planda** yapılandır
- Fiyatları §8.2'deki tabloya göre ayarla

**Beklenen etki:** Dönüşüm oranında 2–3x artış, ARPU'da belirgin sıçrama — tek satır yeni özellik yazmadan.

### Faz 2 — 1–3 ay (Premium'a gerçek bir ruh ver)
7. ✅ **Sağlık Geri Kazanım Zaman Çizelgesi** — `recovery_timeline.dart` +
   `recovery_timeline_screen.dart`. 6 kategori (nikotin, alkol, şeker,
   kafein, ekran, genel), 30+ kilometre taşı. İlk 3 taş ücretsiz, gerisi Pro.
   Zorunlu tıbbi sorumluluk reddi ekranda. AI/ağ maliyeti yok.
8. ✅ **Geleceğe Mektup** — `letter_screen.dart` + `Streak.letter`.
   **Kararın değiştirildiği yer:** Strateji ilk hâlinde bunu Premium
   önermişti. Uygulama sırasında bunun yanlış olduğuna karar verildi —
   kullanıcının KENDİ sözlerini, üstelik kriz anında görmesini paraya
   bağlamak hem etik değil hem özelliğin gücünü yok eder. Tamamen ücretsiz.
   İş değeri dönüşümden değil **bağlılıktan** gelir: mektubunu bırakan
   kullanıcı uygulamayı silmez.
9. ✅ **Haftalık Hayat Raporu** — `weekly_report.dart` +
   `weekly_report_screen.dart`. Son 7 günün tamamlama oranı, temiz gün,
   kazanılan para/su, geçilen eşikler, en güçlü/en zor gün ve gelecek hafta
   için **tek bir odak önerisi**. Öneri suçlayıcı değil uyarlayıcı: sık
   kaçırılan alışkanlık için "hedefi küçültmeyi dene" der.
   **İlk rapor herkese ücretsiz**, sonrakilerde manşet + temel rakamlar
   görünür kalır, derin analiz Pro'ya geçer. Her PAZAR 10:00 bildirimi
   kuruldu (retention motorunun asıl çalıştığı yer bu bildirimdir).
10. ✅ **Mikro-anket altyapısı** — `TriggerEntry` modeli +
    `AppState.triggerLog` + `ui/trigger_sheet.dart`. Kriz atlatıldıktan
    **ve** nüks kaydedildikten sonra tek dokunuşluk "bunu ne tetikledi?"
    sorusu (8 seçenek, her zaman atlanabilir, asla kriz ANINDA sorulmaz).
    Zaman damgası + sonuç (atlatıldı/nüksetti) kaydedilir; 500 kayıtla
    sınırlı (bulut senkronizasyonu şişmesin). Nüks hem kriz ekranından
    hem bırakma menüsünden kaydedilebildiği için her ikisine de bağlandı.
    **Faz 3'ün tüm veri temeli budur — bugün toplamaya başlamazsak
    Risk Penceresi ve Tetikleyici Haritası 3 ay sonra boş çalışır.**

**Faz 2 TAMAMLANDI.** ✅

### Faz 3 — 3–6 ay (kopyalanamaz moat)
11. ✅ **Risk Penceresi Tahmini** — `insights.dart`. 3 saatlik kayan
    pencereyle en yoğun risk aralığı + belirginse gün deseni. En az 4 kayıt
    şartı (az veriyle kesin konuşmak güvenilirliği yok eder). Gece yarısını
    aşan pencereler (23:00–01:00) modülo ile doğru yakalanıyor.
    **Proaktif bildirim**: riskli saatten 1 saat önce, hazırlayıcı tonda
    ("Planın ne?"), yalnızca Pro'ya.
12. ✅ **Tetikleyici Haritası** — `insights_screen.dart`. Baskın tetikleyici,
    her tetikleyicide dayanma oranı, en güçlü ve en kırılgan nokta.
    Ücretsiz kullanıcı desenin VAR OLDUĞUNU görür, ne olduğunu göremez
    (merak boşluğu).
13. ✅ **Kriz Koçu kişiselleştirmesi** — kriz ekranında kullanıcının kendi
    geçmişinden çıkan somut kanıt: "Bu dalgayı daha önce 4 kez atlattın."
    Genel motivasyon sözünden çok daha ikna edici, çünkü itiraz edilemez.
    Veri yoksa hiç gösterilmez.
15. ✅ **Adaptif Zorluk** — son 7 günde çok kaçırılan alışkanlık için ana
    ekranda "hedefi küçültelim mi?" kartı. Ton asla suçlayıcı değil;
    reddedilirse 30 gün tekrar sorulmaz. Kategorideki en büyük terk
    sebebini (başarısızlık utancı) doğrudan hedefler.
14. ✅ **Panik butonu (Sorumluluk Ortağı)** — `supabase_panic_signals.sql` +
    `friends.dart` (PanicSignal, sendPanicSignal/loadPanicSignals/
    acknowledgePanic) + kriz ekranında buton + arkadaşlar ekranında
    sinyal kartı ve "Yanındayım" yanıtı.

    **Bilinçli sınırlama:** Anlık push bildirimi YOK — arkadaş sinyali
    uygulamayı bir sonraki açışında görür. Arayüz bunu kullanıcıya
    açıkça söyler ("uygulamayı açtıklarında görecekler"); krizdeki bir
    insana tutulamayacak bir söz vermek, güvenin en kritik olduğu anda
    yalan söylemek olurdu. Buton yalnızca gerçekten arkadaşı olan
    kullanıcıya gösterilir.

    ⏳ **Anlık push için kalan iş:** FCM (Android) + APNs (iOS) kurulumu,
    cihaz token yönetimi, `panic_signals` tablosuna INSERT trigger'ı ve
    bildirim gönderen Edge Function. Ayrı bir altyapı projesi.

**Faz 3 TAMAMLANDI** (anlık push hariç). ✅

### Ölçülecek metrikler
- Deneme başlatma oranı (hedef: %8–12 / aktif kullanıcı)
- Deneme → ödeme dönüşümü (hedef: %35+)
- Yıllık plan payı (hedef: gelirin %60'ı+)
- 30/60/90 gün abone kalma oranı
- Ücretsiz D30 retention (Premium dönüşümünün öncü göstergesi)
- Ödüllü reklam izleyen → abone dönüşüm oranı

### Kırmızı çizgiler (asla ihlal edilmeyecek)
- Kriz/SOS ekranı hiçbir koşulda ödeme duvarı arkasına alınmaz
- Nüks sonrası 7 gün abonelik teklifi gösterilmez
- "Serini kurtarmak için öde" mekaniği kurulmaz
- Kullanıcı verisi dışa aktarma her zaman ücretsiz kalır
- Var olmayan özellik asla vaat edilmez

---

*Bu strateji, kısa vadeli gelir maksimizasyonu yerine 12+ ay abone kalan, uygulamayı arkadaşlarına öneren ve hayatı gerçekten değişen kullanıcı yaratmak üzerine kuruludur. İkisi çelişirse, uzun vadeli güven kazanır.*
