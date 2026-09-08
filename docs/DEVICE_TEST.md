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
| ch09 (kulübe, L bahçe) | 60 | büyük engel bloğu + kiremit çatı (G19.3) |
| ch19 (gölet) | 60 | su shader'ı; 45'in altı = `WATER_FANCY_ENABLED` kapat |
| ch25 (fener, gece) | 60 | tek OmniLight + karanlık; ışık kırpışması takılıyor mu (G19.5) |
| Hurda ortaya çıkışı (herhangi bahçe) | — | komşu hücre kesilince parça yerden çıkıyor mu; havada duran yok (G19.1) |
| Yürüme modu | 60 | — |
| Açılış: Godot logosu YOK, koyu zemin + ikon; menüde başlık tam okunuyor (G35, simülatörde doğrulandı) | — | gerçek cihazda bir kez bak |
| Arka plana al / geri gel ×3 | ses ve durum korunuyor mu | duraklatma testi |
| Bahçe sonu: KARTPOSTAL | — | düğme panelde görünüyor mu; kart açılıyor, dokununca kapanıyor mu; Günlük → Albüm sekmesinde listeleniyor mu; telefon paylaşım sayfası YOK (eklenti gerekir, bilinen eksik) (G27) |
| Bahçeyi düz sıralarla biç | — | panelde "Düz sıralar" çipi ve kartpostal damgasında DÜZ SIRALAR çıkıyor mu; serbest kesimde çip yok (G28) |
| Bahçede küçük sürprizler | — | bir bahçede en fazla iki: uçurtma / kelebek / top / makineye konan kuş / bulut gölgesi / akşam yanan pencere; hiçbiri oyunu kesmiyor, FPS düşmüyor (G29) |
| Hub selamı ve Günlük yüzdesi | — | saat dilimine göre selam, kalan bahçe sayısı doğru; Günlük başlığında yüzde (G31–G32) |
| Günlük → Kayıtlar | — | kazanılanlar tarihli, kalanlar soluk; bahçe sonunda "Günlüğe yazıldı" satırı tek seferlik (G33) |
| Kulübeye/çite çarp | — | tok bir ses, kısa titreşim ve küçük bir kamera itmesi var mı; çite yaslanıp sürtünürken ses tekrar tekrar çalmıyor mu (G38) |
| Hikâye kartları ve diyaloglar | — | yazı harf harf akıyor mu; ilk dokunuş satırı tamamlıyor, ikincisi sayfayı çeviriyor mu; iki satırlık kartta metin zıplamıyor mu; Ayarlar → "Harf harf yazı" kapatınca hepsi bir anda geliyor mu (G37) |
| Vaka 1 kapanışı: köpeğe isim | — | klavye açılıyor mu, kutu klavyenin üstünde kalıyor mu; çipler tek dokunuşla onaylıyor mu; sonraki bahçede "X durdu" satırı ismi söylüyor mu (G26) |

## Masaüstü (Steam ön izleme, 1600×900)
- Hub → Kasaba sayfası: gökyüzü ve bulutlar kadrajda mı (G19.9). Değilse
  `TownDiorama._fit_camera_aspect` çağrılmamış demektir.
- Diyalog, kartlar, hub sayfaları 1170'lik sütunda mı (G18).

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
