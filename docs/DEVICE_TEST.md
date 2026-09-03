# Cihazda test — kontrol listesi (G16.3)

Bu projedeki her sayı M4 Pro'dan geldi. Aşağıdakiler gerçek bir telefonda,
sırayla, **ilk build'de** yapılır ve sonuçlar README'ye ölçüm olarak yazılır.

## Cihazlar
- Orta seviye Android: Mali-G52 / Adreno 610 sınıfı (ör. Samsung A14, Redmi Note 11).
- Eski iPhone: XR veya 11 (A12/A13).
- Üst seviye biri: ne kadar tepe payı olduğunu görmek için.

## Nasıl ölçülür
1. Ayarlar → uzun bas "Sürüm" satırına → **Performans göstergesi** açılır
   (sağ üstte fps / çizim / üçgen). Test bitince aynı yerden kapat.
2. Her ekranda 20 saniye dur, **en düşük** fps'i yaz (ortalama değil).

## Sıra ve eşikler
| Ekran | Hedef | Kritik |
|---|---|---|
| Ana menü | 60 | — |
| Prolog kartları → yol bölümü | 60 | ilk 10 saniye: siyah ekran > 2 s ise shader ısıtma yetersiz |
| **Kasaba (hub)** | 60 | 40'ın altı = LOD turu gerekir; bu ekran oyunun **ilk** ekranı |
| ch01 (küçük bahçe, gündüz) | 60 | 50'nin altı = tuft yoğunluğu |
| ch04 (yağmur) | 60 | yağmur parçacığı maliyeti |
| ch06 (gün batımı → gece akışı) | 60 | gölge + fireflies |
| Hasat (26×38 ızgara) | 60 | en büyük ızgara |
| Yürüme modu | 60 | — |
| Arka plana al / geri gel ×3 | ses ve durum korunuyor mu | duraklatma testi |

## Isı ve pil
- 15 dakika kesintisiz hasat: cihaz ısınıyor mu, fps düşüyor mu (thermal throttling)?
- Pil %'si başlangıç/bitiş.

## Bellek
- Godot çıktısında `[olcum] tepe statik` satırı; 300 MB üstü düşük cihazda öldürülür.

## Dokunma
- Pad sürükleme, İN/BİN, makine seçici, hub sayfa geçişleri — her biri tek elle,
  başparmakla, telefonu kılıf içinde tutarken.

## Sonuç nereye
README'ye `### Cihaz ölçümü — <cihaz> — <tarih>` başlığıyla tablo. Ölçülmemiş
hiçbir eşik "geçti" sayılmaz.
