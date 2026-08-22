# textures/

Sprint G1'in aradığı dosyalar. Yoksa fallback devreye girer + konsol uyarısı:

| Dosya | Yoksa ne olur |
| --- | --- |
| `grass_albedo.png` | Düz renk zemin |
| `grass_normal.png` | Normal map'siz zemin |
| `grass_blade_tuft.png` | Prosedürel üçgen silüetli tuft dokusu üretilir |

Ek olarak §13 "fake AO" için objelerin altına radyal koyu daire dokusu gerekir
(SSAO Mobile renderer'da çalışmadığı için tek yöntem bu).
