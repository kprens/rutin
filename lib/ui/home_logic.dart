import '../l10n.dart';
import '../models.dart';

/// Home ekranından ayrıştırılmış saf iş mantığı fonksiyonları.
///
/// Widget'a bağımlı değildir; state veya BuildContext gerektirmez, bu
/// yüzden doğrudan test edilebilir.

/// Günün saatine göre uygun selamlama metnini döndürür.
String greetingFor(int hour) {
  if (hour < 12) return t('Günaydın,', 'Good morning,');
  if (hour < 18) return t('İyi günler,', 'Good afternoon,');
  return t('İyi akşamlar,', 'Good evening,');
}

/// Tamamlanan / toplam alışkanlık oranını 0.0–1.0 arasında döndürür.
/// Toplam sıfırsa bölme hatası vermemek için 0.0 döner.
double progressRatio(int done, int total) => total == 0 ? 0.0 : done / total;

/// Geriye kalan alışkanlık sayısını döndürür (negatif olamaz).
int habitsRemaining(int done, int total) => (total - done).clamp(0, total);

/// Bir dizi bırakma serisi (streak) içindeki en uzun "temiz gün" sayısını
/// döndürür. Liste boşsa 0 döner.
int longestCleanStreak(List<Streak> streaks) =>
    streaks.fold<int>(0, (m, st) => st.days > m ? st.days : m);
