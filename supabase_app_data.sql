-- ============================================================
-- Rutin — Hesap bazlı uygulama verisi (streak, görev, su takibi, takvim...)
-- Supabase Dashboard → SQL Editor → New query → yapıştır → Run
--
-- Amaç: Kullanıcı hesabıyla giriş yaptığında tüm uygulama verisi tek bir
-- JSON satırı olarak burada tutulur. Çıkış yapıp başka bir hesaba
-- geçildiğinde cihazdaki veri sıfırlanır (bkz. lib/store.dart); aynı
-- hesaba tekrar giriş yapıldığında veri buradan geri yüklenir.
-- ============================================================

create table public.app_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.app_data enable row level security;

create policy "app_data: kullanici kendi verisini okur"
  on public.app_data for select to authenticated
  using (user_id = auth.uid());

create policy "app_data: kullanici kendi verisini olusturur"
  on public.app_data for insert to authenticated
  with check (user_id = auth.uid());

create policy "app_data: kullanici kendi verisini gunceller"
  on public.app_data for update to authenticated
  using (user_id = auth.uid());

create policy "app_data: kullanici kendi verisini siler"
  on public.app_data for delete to authenticated
  using (user_id = auth.uid());
