-- Rutin — Panik Sinyali (Sorumluluk Ortağı)
--
-- Kullanıcı kriz anında "şu an zorlanıyorum" sinyali gönderir; arkadaşları
-- bunu uygulamayı açtıklarında görür ve destek olabilir.
--
-- ÖNEMLİ SINIRLAMA: Bu tasarım ANLIK PUSH BİLDİRİMİ GÖNDERMEZ.
-- Rutin şu anda yalnızca yerel bildirim (flutter_local_notifications)
-- kullanıyor; başka bir kullanıcının telefonuna bildirim göndermek için
-- FCM (Android) + APNs (iOS) altyapısı ve cihaz token yönetimi gerekir.
-- Bu yüzden arkadaş, sinyali uygulamayı BİR SONRAKİ AÇIŞINDA görür.
-- Uygulama arayüzü bunu kullanıcıya AÇIKÇA söyler — "anında ulaşacak"
-- gibi yanlış bir vaatte bulunulmaz.
--
-- Push altyapısı kurulduğunda: bu tabloya bir INSERT trigger'ı eklenip
-- Edge Function üzerinden bildirim gönderilecek şekilde genişletilebilir.
--
-- Supabase SQL Editor'de bir kez çalıştır.

create table if not exists public.panic_signals (
  id          bigserial primary key,
  user_id     uuid not null references auth.users (id) on delete cascade,
  -- Sinyalin ilgili olduğu bırakma kaydının adı (ör. "Sigara").
  -- Sadece görüntüleme amaçlı; hassas veri barındırmaz.
  streak_name text not null default '',
  created_at  timestamptz not null default now(),
  -- Arkadaş "gördüm / yanındayım" dediğinde işaretlenir.
  acknowledged_by uuid references auth.users (id) on delete set null,
  acknowledged_at timestamptz
);

create index if not exists panic_signals_user_created_idx
  on public.panic_signals (user_id, created_at desc);

alter table public.panic_signals enable row level security;

-- Kendi sinyalini oluşturabilir.
drop policy if exists "panic insert own" on public.panic_signals;
create policy "panic insert own"
  on public.panic_signals for insert
  with check (auth.uid() = user_id);

-- Kendi sinyallerini ve KABUL EDİLMİŞ arkadaşlarının sinyallerini görebilir.
drop policy if exists "panic select own or friends" on public.panic_signals;
create policy "panic select own or friends"
  on public.panic_signals for select
  using (
    auth.uid() = user_id
    or exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester = auth.uid() and f.addressee = panic_signals.user_id)
          or
          (f.addressee = auth.uid() and f.requester = panic_signals.user_id)
        )
    )
  );

-- Arkadaş "yanındayım" olarak işaretleyebilir (yalnızca acknowledged alanları).
drop policy if exists "panic ack by friend" on public.panic_signals;
create policy "panic ack by friend"
  on public.panic_signals for update
  using (
    exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester = auth.uid() and f.addressee = panic_signals.user_id)
          or
          (f.addressee = auth.uid() and f.requester = panic_signals.user_id)
        )
    )
  );

-- Kendi sinyalini silebilir.
drop policy if exists "panic delete own" on public.panic_signals;
create policy "panic delete own"
  on public.panic_signals for delete
  using (auth.uid() = user_id);
