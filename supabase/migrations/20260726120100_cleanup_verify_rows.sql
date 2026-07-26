-- Kurulum doğrulaması sırasında yazılan test satırlarını temizler.
-- (analytics_events tablosunun ve RLS politikalarının gerçekten çalıştığı
--  anon INSERT ile doğrulanmıştı; bu satırların üründe bir karşılığı yok.)
delete from public.analytics_events
where name in ('_verify_setup', '_verify_rls');
