-- ============================================================
-- Rutin — Ürün analitiği (dönüşüm hunisi + retention ölçümü)
-- Supabase Dashboard → SQL Editor → New query → yapıştır → Run
--
-- NEDEN KENDİ TABLOMUZ (Firebase/Amplitude yerine):
--   • Supabase zaten kurulu — yeni bağımlılık, yeni SDK, yeni native
--     yapılandırma dosyası gerekmiyor.
--   • Rutin bir BAĞIMLILIK BIRAKMA uygulaması. Kullanıcının nüks ettiği anı
--     üçüncü taraf bir reklam/analitik şirketine göndermek, hem etik olarak
--     savunulamaz hem de App Privacy / Data Safety beyanlarını ("üçüncü
--     taraflarla paylaşılan veri") ciddi şekilde ağırlaştırır. Veri kendi
--     veritabanımızda kalınca beyan basit ve dürüst kalır.
--   • Huni analizi SQL'in en iyi olduğu iştir (bkz. aşağıdaki hazır sorgular).
--
-- GİZLİLİK KURALI (lib/analytics.dart bunu zorunlu kılar):
--   Bu tabloya ASLA kişisel veri yazılmaz. Alışkanlık/bırakma ADI, kullanıcı
--   adı, e-posta, serbest metin, mektup içeriği YASAK. Yalnızca olay adı ve
--   sayısal/enum parametreler.
-- ============================================================

create table if not exists public.analytics_events (
  id          bigserial primary key,

  -- Cihaz başına anonim kimlik (uygulama ilk açılışta üretir).
  -- Kullanıcı henüz giriş yapmadan yaşanan adımları (onboarding, paywall)
  -- ölçebilmek için gerekli — huninin en kritik kısmı girişten ÖNCEDİR.
  install_id  uuid not null,

  -- Giriş yapılmışsa hesap. Hesap silindiğinde bu kullanıcının olayları da
  -- silinir (App Store 5.1.1(v) hesap silme zorunluluğuyla tutarlı).
  user_id     uuid references auth.users (id) on delete cascade,

  name        text not null,
  params      jsonb not null default '{}'::jsonb,

  app_version text,
  platform    text,

  -- Cihazda oluştuğu an. Olaylar çevrimdışıyken kuyruğa alınıp sonra
  -- gönderildiği için sunucu saati (created_at) ile farklı olabilir;
  -- huni analizinde client_ts kullanılmalı.
  client_ts   timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists analytics_events_name_ts_idx
  on public.analytics_events (name, client_ts desc);

create index if not exists analytics_events_install_idx
  on public.analytics_events (install_id, client_ts);

alter table public.analytics_events enable row level security;

-- İstemci yalnızca YAZAR. Giriş yapmamış kullanıcı da yazabilmeli (huninin
-- onboarding kısmı girişten önce yaşanıyor), ama başkasının hesabına olay
-- yazamaz.
drop policy if exists "analytics: insert own" on public.analytics_events;
create policy "analytics: insert own"
  on public.analytics_events for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());

-- Kullanıcı kendi olaylarını görebilir (GDPR erişim hakkı). Raporlama
-- Dashboard'dan service_role ile yapılır; istemcinin okumaya ihtiyacı yok.
drop policy if exists "analytics: select own" on public.analytics_events;
create policy "analytics: select own"
  on public.analytics_events for select to authenticated
  using (user_id = auth.uid());


-- ============================================================
-- HAZIR SORGULAR — Dashboard → SQL Editor'de çalıştır
-- ============================================================

-- 1) SATIN ALMA HUNİSİ (son 30 gün, cihaz bazlı)
--    Her adımda kaç cihaz var ve bir öncekine göre yüzde kaçı geçti.
--
-- with steps as (
--   select
--     count(distinct install_id) filter (where name = 'app_open')          as acilis,
--     count(distinct install_id) filter (where name = 'onboarding_start')  as onb_basladi,
--     count(distinct install_id) filter (where name = 'onboarding_complete') as onb_bitti,
--     count(distinct install_id) filter (where name = 'paywall_view')      as paywall_gordu,
--     count(distinct install_id) filter (where name = 'plan_select')       as plan_secti,
--     count(distinct install_id) filter (where name = 'purchase_start')    as satin_alma_basladi,
--     count(distinct install_id) filter (where name = 'purchase_success')  as satin_aldi
--   from public.analytics_events
--   where client_ts > now() - interval '30 days'
-- )
-- select * from steps;

-- 2) PAYWALL NEREDEN AÇILIYOR ve hangisi dönüşüyor
--    `source` parametresi bunu ölçmek için var.
--
-- select params->>'source' as kaynak,
--        count(*) filter (where name = 'paywall_view')     as goruntuleme,
--        count(*) filter (where name = 'purchase_success') as satis
-- from public.analytics_events
-- where name in ('paywall_view','purchase_success')
--   and client_ts > now() - interval '30 days'
-- group by 1 order by goruntuleme desc;

-- 3) SATIN ALMA NEDEN BAŞARISIZ (F-003 gibi hatalar burada görünür)
--
-- select params->>'plan' as plan, params->>'reason' as sebep, count(*)
-- from public.analytics_events
-- where name = 'purchase_fail' and client_ts > now() - interval '30 days'
-- group by 1,2 order by 3 desc;

-- 4) RETENTION (D1 / D7 / D30) — kurulum gününe göre kohort
--
-- with ilk as (
--   select install_id, min(client_ts::date) as gun0
--   from public.analytics_events where name = 'app_open' group by 1
-- ),
-- aktif as (
--   select distinct e.install_id, i.gun0, (e.client_ts::date - i.gun0) as gun
--   from public.analytics_events e join ilk i using (install_id)
--   where e.name = 'app_open'
-- )
-- select gun0,
--        count(distinct install_id) filter (where gun = 0)  as kurulum,
--        count(distinct install_id) filter (where gun = 1)  as d1,
--        count(distinct install_id) filter (where gun = 7)  as d7,
--        count(distinct install_id) filter (where gun = 30) as d30
-- from aktif group by gun0 order by gun0 desc;

-- 5) PAYWALL'I GÖRÜP VAZGEÇENLER — nerede kaybediyoruz
--
-- select params->>'selected_plan' as secili_plan, count(*)
-- from public.analytics_events
-- where name = 'paywall_dismiss' and client_ts > now() - interval '30 days'
-- group by 1 order by 2 desc;
