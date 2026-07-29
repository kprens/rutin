# Cevap bekleyen sorular

## S-1 · GRUP B onayı (protokol md. 4 gereği ayrı onay)
`risk_of_fix: high` üç bulgu — QUAL-001 (store.dart bölme), DEVOPS-001 (21 paket yükseltme),
SEC-001 (makbuz doğrulama mimarisi). Uygulama App Store incelemesinde.
**Soru:** Bunlar şimdi mi uygulansın, yoksa inceleme sonuçlandıktan sonra mı?

## S-2 · QUAL-003 · RError bileşeni
`lib/ui/rutin_ui.dart:565` — kullanılmıyor. Kaldırılsın mı, yoksa hata durumlarında
kullanılmak üzere korunsun mu? (Ürün kararı: hata ekranları planlanıyor mu?)

## S-3 · ARCH-003 · main_ui.dart
Yalnızca `main.dart`'ı çağıran mükerrer entrypoint. Bir geliştirme alışkanlığına
(`flutter run -t lib/main_ui.dart`) bağlı mı, yoksa kaldırılabilir mi?

## S-4 · DEVOPS-002 · CI'da iOS derlemesi
macOS runner dakikaları ücretlidir (public repo'da ücretsiz olabilir ama
kotanız GitHub'a bağlı). iOS derleme işi eklenmesini onaylıyor musunuz?
