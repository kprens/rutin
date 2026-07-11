-- ============================================================
-- Rutin — Sosyal katman veritabanı şeması + güvenlik kuralları
-- Supabase Dashboard → SQL Editor → New query → yapıştır → Run
-- ============================================================

-- Kullanıcı profilleri
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  friend_code text not null unique,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: girisli herkes okuyabilir"
  on public.profiles for select to authenticated using (true);

create policy "profiles: kendi profilini olusturur"
  on public.profiles for insert to authenticated with check (id = auth.uid());

create policy "profiles: kendi profilini gunceller"
  on public.profiles for update to authenticated using (id = auth.uid());

-- Arkadaşlıklar (istek → onay)
create table public.friendships (
  id bigint generated always as identity primary key,
  requester uuid not null references public.profiles(id) on delete cascade,
  addressee uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  unique (requester, addressee),
  check (requester <> addressee)
);

alter table public.friendships enable row level security;

create policy "friendships: taraflar gorur"
  on public.friendships for select to authenticated
  using (requester = auth.uid() or addressee = auth.uid());

create policy "friendships: istek gonderme"
  on public.friendships for insert to authenticated
  with check (requester = auth.uid());

create policy "friendships: alici onaylar"
  on public.friendships for update to authenticated
  using (addressee = auth.uid());

create policy "friendships: taraflar silebilir"
  on public.friendships for delete to authenticated
  using (requester = auth.uid() or addressee = auth.uid());

-- Paylaşılan streak özetleri (sadece kullanıcının paylaşmayı SEÇTİKLERİ)
create table public.shared_streaks (
  id bigint not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  start_ms bigint not null,
  best_days int not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

alter table public.shared_streaks enable row level security;

create policy "shared_streaks: sahibi ve onayli arkadaslar gorur"
  on public.shared_streaks for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.friendships f
      where f.status = 'accepted'
        and (
          (f.requester = auth.uid() and f.addressee = user_id)
          or (f.addressee = auth.uid() and f.requester = user_id)
        )
    )
  );

create policy "shared_streaks: kendi kaydini ekler"
  on public.shared_streaks for insert to authenticated
  with check (user_id = auth.uid());

create policy "shared_streaks: kendi kaydini gunceller"
  on public.shared_streaks for update to authenticated
  using (user_id = auth.uid());

create policy "shared_streaks: kendi kaydini siler"
  on public.shared_streaks for delete to authenticated
  using (user_id = auth.uid());
