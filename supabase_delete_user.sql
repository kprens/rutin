-- Hesap silme fonksiyonu (Play Store zorunluluğu).
-- Supabase Dashboard → SQL Editor → New query → yapıştır → Run
-- Kullanıcı yalnızca KENDİ hesabını silebilir; profil, arkadaşlıklar ve
-- paylaşılan streak'ler foreign key cascade ile birlikte silinir.

create or replace function public.delete_user()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = auth.uid();
$$;

revoke execute on function public.delete_user() from anon;
grant execute on function public.delete_user() to authenticated;
