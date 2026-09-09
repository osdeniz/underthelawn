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
| Bahçe ortasında uygulamayı ÖLDÜR | — | telefonun uygulama değiştiricisinden kapat, yeniden aç, DEVAM ET: aynı bahçe, aynı kesim, aynı saat, bulunmuş kanıtlar duruyor mu; biten bahçeden sonra DEVAM ET hub açıyor mu (G42) |
| Arka plana al / geri gel ×3 | ses ve durum korunuyor mu | duraklatma testi |
| Fotoğraf modu | — | Duraklat → FOTOĞRAF: arayüz çekiliyor, orta bant aydınlık kalıyor mu; sürükleyince bahçenin çevresinde dönüyor mu; deklanşörden sonra "Albüme kondu" ve Günlük → Albüm'de kart var mı; kapatınca oyun kamerası ve arayüz geri dönüyor mu (G47) |
| Kartpostalda önce/sonra | — | bitmiş bahçenin fotoğrafının sol altında biçilmemiş halin küçük baskısı ve "önce" yazısı var mı; yarısı kesilmiş bir bahçeye DEVAM ET ile dönüp bitirince "önce" baskısı YOK (yalan olurdu) (G45) |
| Bahçe sonu: KARTPOSTAL | — | düğme panelde görünüyor mu; kart açılıyor, dokununca kapanıyor mu; Günlük → Albüm sekmesinde listeleniyor mu; telefon paylaşım sayfası YOK (eklenti gerekir, bilinen eksik) (G27) |
| Kasaba deseni fark ediyor | — | iki bahçeyi desenli bitirdikten sonra yeni bahçede yan çitte komşular var mı; kulübenin altında ya da duvarın içinde kalmıyorlar mı; ilk gelişlerinde tek satır çıkıp bir daha çıkmıyor mu (G50) |
| Bahçeyi düz sıralarla biç | — | panelde "Düz sıralar" çipi ve kartpostal damgasında DÜZ SIRALAR çıkıyor mu; serbest kesimde çip yok (G28) |
| Bahçede küçük sürprizler | — | bir bahçede en fazla iki: uçurtma / kelebek / top / makineye konan kuş / bulut gölgesi / akşam yanan pencere; hiçbiri oyunu kesmiyor, FPS düşmüyor (G29) |
| Hub selamı ve Günlük yüzdesi | — | saat dilimine göre selam, kalan bahçe sayısı doğru; Günlük başlığında yüzde (G31–G32) |
| Sayfaları parmakla kaydır | — | Ayarlar, Günlük ve hub kart sütunu ekranın herhangi bir yerinden sürüklenerek kayıyor mu; Ayarlar'da Dil satırına ulaşılıyor mu; "İlerlemeyi Sil" satırların üstüne binmiyor mu (G53) |
| Küçük yazı | — | "Yeni Oyun" onay kutusundaki İptal / Sil ve baştan başla yazıları okunur büyüklükte mi (G53) |
| Kasabada bir şey onar | — | kutlama sahnesi kasabanın üstünde mi oynuyor, siyah ekran üstünde mi (G53) |
| Vaka kapanışında Şerif'in sayfası | — | kavuşma/konvoy/kapı kartından sonra parşömen sayfa geliyor mu; kendi kurduğun çıkarımlar sayfada mı; köpeğin adı geçiyor mu; ilk dokunuş yazıyı bitirip ikincisi kapatıyor mu (G52) |
| Açılışta ses | — | menüde ve kartlarda kuş sesi bunaltıcı değil mi; prolog kartlarında kuş YOK; açılışta koyu ekran değil oyunun ikonu görünüyor mu (G51) |
| Günlük → Bulgular: iki bulguyu bağla | — | bir bulguya dokununca kenar çizgisi kalınlaşıyor mu; ikinciye dokununca altta Şerif'in cevabı çıkıyor mu; yanlış çift bir şey kaybettirmiyor mu; kurulan çıkarım Vaka Notları'nın sonunda ÇIKARIMLAR altında duruyor mu (G48) |
| Günlük → Kayıtlar | — | kazanılanlar tarihli, kalanlar soluk; bahçe sonunda "Günlüğe yazıldı" satırı tek seferlik (G33) |
| Kulübeye/çite çarp | — | tok bir ses, kısa titreşim ve küçük bir kamera itmesi var mı; çite yaslanıp sürtünürken ses tekrar tekrar çalmıyor mu (G38) |
| Kartları basılı tutarak atla | — | çubuk dolarken görünüyor mu; parmağı kaldırınca sıfırlanıyor mu; kartlara sadece dokunup beklerken KENDİ KENDİNE atlamıyor mu (G40) |
| Klavye/kontrolcü ile menüler (masaüstü) | — | bir tuşa basınca odak halkası çıkıyor mu; oklarla satırlar arasında geziliyor, Enter basıyor mu; fareye/dokunmaya geçince halka kayboluyor mu (G43) |
| Köpeğin burnu | — | 3., 8. ve 15. buluşta bir kez "artık daha uzaktan buluyor" satırı geliyor mu; sonrasında köpek gerçekten daha uzaktan duruyor mu (G46) |
| Yağmurun gelişi | — | yağmurlu bir bölümde (ör. Komşunun Bahçesi) ilk yarım dakika kuru mu; uzaktan bir gümbürtü ve rüzgâr duyuluyor mu; ışık düzleştikten SONRA damlalar başlıyor mu; uygulamayı öldürüp DEVAM ET ile dönünce yağmur zaten yağıyor mu (G49) |
| Küçük cevaplar | — | diyalogda yeni satırda portre hafifçe yükseliyor mu; bahçenin başındaki biçme sesi sonundakinden daha kalın mı; makineyi 6 sn park edince köpeğin başı düşüyor, hareket edince kalkıyor mu (G44) |
| Düğmelere bas | — | her düğme (hub kutuları, ayar satırları, panel kapıları, albüm kapakları) parmağın altında hafifçe küçülüyor mu; Ayarlar → "Azaltılmış hareket" açıkken küçülme, kart kayması ve çarpma itmesi duruyor ama kilitli satır yine renkle cevap veriyor mu (G41) |
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
