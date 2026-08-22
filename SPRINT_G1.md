Bu proje, "Under the Lawn" adlı mobil çim biçme oyununun Godot 4 (4.3+) ile inşasıdır. Oyun daha önce SwiftUI + SceneKit ile prototiplendi ve tüm sistemler, algoritmalar, ayar değerleri proje kökündeki REFERENCE.md dosyasında eksiksiz tarif edildi. REFERENCE.md bu projenin kaynak gerçeğidir (source of truth): her sistemi oradaki spesifikasyona göre kur, oradaki sayıları kullan, kafana göre değer uydurma. Bir konuda REFERENCE.md ile bu prompt çelişirse bu prompt kazanır.

=== PROJE KURULUMU ===
- Godot 4.3+ (GDScript), RENDERER: Mobile (Forward+ değil — hedef iOS/Android)
- Portre yönelim (1170x2532 taban çözünürlük, stretch mode: canvas_items değil — 3D oyun, viewport)
- Klasör yapısı: scenes/ scripts/ resources/ textures/ audio/ ui/
- Ana sahne: Main.tscn (Node3D kök) + GameState autoload singleton
- Git kullanılıyor: her sprint sonunda anlamlı commit mesajı öner

=== ÖNEMLİ PLATFORM DÜZELTMELERİ (REFERENCE.md'ye ek) ===
1. SSAO KULLANMA: Godot'un SSAO'su Mobile renderer'da çalışmaz. Onun yerine REFERENCE.md §13'teki "fake AO" yaklaşımı (objelerin altında radyal koyu daire dokuları) ana yöntem. WorldEnvironment'ta SSAO satırı hiç açılmayacak.
2. Haptic: Input.vibrate_handheld(duration_ms) tek tip titreşimdir; REFERENCE.md §15'teki hafif/orta/success ayrımını süreyle taklit et (hafif=10ms, orta=25ms, success=iki kısa darbe). Frame başına 1 titreşim limiti aynen geçerli.
3. Ses: runtime sentez YAPMA. audio/ klasöründe şu dosyaları arayacak şekilde kur: mower_engine_loop.ogg, grass_cut.ogg, discovery_chime.ogg, ambient_birds_loop.ogg. Dosya yoksa sessiz devam et ve konsola uyarı yaz (ben gerçek dosyaları ekleyeceğim). Volume/pitch davranışları REFERENCE.md §14'teki gibi (motor rölanti/hareket lerp'i, biçmede pitch varyantı, mute kalıcı tercih — ConfigFile).

=== ÇALIŞMA KURALLARI ===
- SPRINT BAZLI çalışıyoruz. Bu promptta yalnızca SPRINT G1 kapsamı var. Kapsam dışına ÇIKMA — sonraki sistemleri (diğer mower'lar, karakter, havuz, çevre, secret) ben ayrıca isteyeceğim.
- Her sprint sonunda: proje hatasız açılmalı/çalışmalı, değişen dosyaları ve test talimatını kısaca özetle.
- Kod düzeni: tüm ayarlanabilir sayılar tek bir scripts/game_config.gd dosyasında (REFERENCE.md §17'deki isimlerle), sahne kurulumu kodla değil mümkün olduğunca .tscn yapısıyla, mantık scriptlerde.
- Performans hedefi: gerçek telefonda 60fps. Tuft'lar için MultiMeshInstance3D ZORUNLU (REFERENCE.md §18).

=== SPRINT G1 KAPSAMI: ÇEKİRDEK HİS ===
Amaç: tek lawn + tek mower (push) + biçme + striping + kamera + minimal HUD. Bu sprint'in tek sorusu: "biçmek Godot'ta da tatmin ediyor mu?"

1. VERİ MODELİ (scripts/lawn_model.gd — saf GDScript, render'dan bağımsız):
REFERENCE.md §3'ü birebir uygula: 16x24 grid, CellState enum, mow() sonuç tipleri, engeller (çiçek tarhı 2 hücre, taş 1 hücre, havuz 12 hücre TEK çarpışma dikdörtgeni, şezlong 1 hücre — havuzun GÖRSELİ bu sprintte yok, sadece model + yer tutucu gri plane), secret yerleşim algoritması (model hazır olsun ama görsel/keşif akışı sonraki sprintte).

2. ZEMİN + STRIPING (REFERENCE.md §4-5):
- Tek sürekli plane + çim albedo/normal dokusu (textures/ klasöründe ara: grass_albedo.png, grass_normal.png; yoksa düz renk fallback + konsol uyarısı)
- 16x24 ImageTexture tint haritası, shader'da albedo çarpımı, linear filtre
- YÖN BAZLI striping: 4 ton (K en açık, G en koyu — değerler §4'te), yeniden şeritleme (biçik hücreden farklı yön kovasıyla geçilince ton güncellenir), secret hücresi toprak tonu
- İlk çalıştırmada tint satır ekseninin görsel eksenle eşleştiğini DOĞRULA (y-flip klasik hata — REFERENCE.md §18 tuzak 5)

3. UZUN ÇİM TUFTLARI (REFERENCE.md §5):
- 8 varyant MultiMesh, hücre başına 7 tutam crossed-quad, boy/ölçü değerleri §5'te
- Tuft dokusu: textures/grass_blade_tuft.png ara; yoksa basit üçgen silüetli prosedürel Image üret
- Rüzgar sway'i vertex shader'da (formül §5'te), kök sabit
- Biçme animasyonu: tutam mower yönüne yatarak 0.1 sn'de kaybolur (MultiMesh instance'ı gizle + o hücrede tek seferlik yatma efekti için ayrı geçici mesh kullanılabilir — performanslı çözümü sen seç)

4. PUSH MOWER + KONTROL (REFERENCE.md §6-7):
- Model: §6'daki push mower primitive kombinasyonu (kırmızı metalik deck, tekerlekler, kol, egzoz — CSG değil, MeshInstance3D'lerle)
- Hareket çekirdeği §7'deki formüllerle BİREBİR: throttle (basılıyken hareket, bırakınca 0.55 sn doğal durma), 0.4 sn hızlanma, smooth steering (smoothing 9.0, hız-yarıçap faktörü 0.45), duvar kırpma, daire-dikdörtgen engel itmesi
- Kontrol: parmak basılıyken kamera-göreli sürükle-yönlendir (§7 Push bölümü, 8pt eşik)
- Biçme: deck yarıçapı 0.7 içindeki hücreler, frame başına tek haptic + tek ses

5. KAMERA (REFERENCE.md §10):
- Chase kamera, FOV 55, mid preset (5.0 / 4.2 / 2.2), pozisyon lerp 4.0/sn, yaw lerp 2.6/sn
- %100'de kuşbakışı ödül geçişi (y=30, lerp 1.8/sn)

6. IŞIK/ATMOSFER (REFERENCE.md §13, SSAO HARİÇ):
- DirectionalLight (açı/renk/yoğunluk §13), gölgeler açık (yumuşak), ambient, gökyüzü degradesi (ProceduralSkyMaterial ile üst/ufuk renkleri), fog 26-70
- Mower altına fake AO dairesi

7. MİNİMAL HUD (ui/, Control tabanlı):
- Üstte "%N biçildi" + yeşil ilerleme kapsülü, sağ üstte mute butonu
- %100'de "LAWN COMPLETE" + hücre sayısı + süre + RESTART butonu (restart: model reset + secret'lar yeniden dağıtılır + tint haritası sıfırlanır)
- UI dokunuşları 3D sahneye geçmemeli

Bu sprintte YAPMA: traktör, robot, sürücü karakteri, havuz görseli, çevre (ev/yol/ağaç/çit/arabalar), secret keşif akışı, parçacıklar, bulutlar. Hepsi sonraki sprintlerde REFERENCE.md'den sırayla gelecek.

Bitirince: değişen dosyalar, bilinen eksikler, ve benim telefonda neyi test etmem gerektiğini (his kriterleri) 5 maddede özetle.