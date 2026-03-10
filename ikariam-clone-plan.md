# Ikariam Klonu — Detaylı Uygulama Planı

## Tech Stack

| Katman | Teknoloji | Neden |
|--------|-----------|-------|
| **Frontend** | Flutter + Flame Engine | Tek codebase ile mobil + web + desktop; Flame ile 2D harita render |
| **Backend** | Supabase (PostgreSQL + Edge Functions + Realtime) | Auth, DB, Realtime, Storage, Cron — hepsi hazır |
| **Zamanlayıcı** | pg_cron + Edge Functions | Kaynak üretimi, bina/araştırma tamamlama tick'leri |
| **State Management** | Riverpod | Reaktif state, Supabase Realtime stream entegrasyonu |
| **Harita Render** | Flame + CustomPainter | İzometrik tile-based ada ve dünya haritası |

---

## Faz 1 — Temel Altyapı ve Auth (Hafta 1-2)

### 1.1 Supabase Proje Kurulumu
- Supabase projesi oluştur
- PostgreSQL şeması tasarla (aşağıdaki ER diyagramına bak)
- Row Level Security (RLS) politikaları tanımla
- Edge Functions ortamını kur

### 1.2 Authentication Sistemi
- Supabase Auth ile email/şifre kayıt-giriş
- Google/Apple OAuth entegrasyonu (opsiyonel)
- Oyuncu profili oluşturma (isim seçme, avatar)
- İlk giriş → otomatik şehir yerleştirme

### 1.3 Flutter Proje İskeleti
- Flutter projesi oluştur (web + mobile + desktop)
- Klasör yapısı: feature-based architecture
- Riverpod provider yapısı
- Supabase Flutter SDK entegrasyonu
- GoRouter ile navigasyon

```
lib/
├── core/               # Ortak utility, theme, constants
│   ├── constants/      # Oyun sabitleri (bina maliyetleri, birim statları)
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/           # Giriş, kayıt, profil
│   ├── city/           # Şehir görünümü, bina yönetimi
│   ├── world_map/      # Dünya/ada haritası
│   ├── military/       # Kışla, birlik eğitimi, savaş
│   ├── research/       # Araştırma ağacı
│   ├── trade/          # Ticaret, pazar
│   ├── diplomacy/      # İttifak, mesajlaşma
│   └── ranking/        # Sıralama tabloları
├── models/             # Veri modelleri (Freezed)
├── services/           # Supabase service layer
└── widgets/            # Paylaşılan widget'lar
```

---

## Faz 2 — Kaynak Sistemi ve Şehir Yönetimi (Hafta 3-5)

### 2.1 Kaynak Türleri
| Kaynak | Açıklama | Üretim Yeri |
|--------|----------|-------------|
| **Ahşap (Wood)** | Temel inşaat malzemesi | Kereste Kampı (her adada) |
| **Mermer (Marble)** | İleri seviye binalar için | Mermer Ocağı (bazı adalarda) |
| **Kristal (Crystal)** | Araştırma ve ileri birimler | Kristal Madeni (bazı adalarda) |
| **Kükürt (Sulfur)** | Askeri birimler ve cephane | Kükürt Çukuru (bazı adalarda) |
| **Altın (Gold)** | Vergi geliri, ticaret | Şehir nüfusundan otomatik |

### 2.2 Kaynak Üretim Mekanizması
- Her şehrin saatlik kaynak üretim hızı var
- Üretim = (işçi_sayısı × bina_seviyesi × araştırma_bonusu)
- pg_cron ile her 5 dakikada kaynak güncelleme tick'i çalışır
- Edge Function: `update-resources` — tüm aktif şehirlerin kaynaklarını hesaplar

```sql
-- Örnek: Kaynak güncelleme fonksiyonu
CREATE OR REPLACE FUNCTION update_city_resources()
RETURNS void AS $$
BEGIN
  UPDATE cities SET
    wood = LEAST(wood + (wood_production_rate * interval_minutes / 60), warehouse_capacity),
    marble = LEAST(marble + (marble_production_rate * interval_minutes / 60), warehouse_capacity),
    crystal = LEAST(crystal + (crystal_production_rate * interval_minutes / 60), warehouse_capacity),
    sulfur = LEAST(sulfur + (sulfur_production_rate * interval_minutes / 60), warehouse_capacity),
    gold = gold + (tax_income_rate * interval_minutes / 60),
    last_resource_update = NOW()
  WHERE last_resource_update < NOW() - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql;
```

### 2.3 Şehir Binası Sistemi

#### Bina Kategorileri

**Yönetim Binaları:**
| Bina | Maks Seviye | İşlev |
|------|-------------|-------|
| Belediye Binası (Town Hall) | 40 | Ana bina, şehir seviyesi, nüfus kapasitesi |
| Depo (Warehouse) | 40 | Kaynak depolama kapasitesi |
| Müze (Museum) | — | Kültürel eşya sergileme, memnuniyet bonusu |
| Taverna (Tavern) | 40 | Şarap ile halk memnuniyeti artırma |

**Kaynak Binaları:**
| Bina | Maks Seviye | İşlev |
|------|-------------|-------|
| Kereste Kampı (Saw Mill) | — | Ada geneli ahşap üretimi |
| Lüks Kaynak Ocağı | — | Ada özel kaynağı (mermer/kristal/kükürt) |

**Askeri Binalar:**
| Bina | Maks Seviye | İşlev |
|------|-------------|-------|
| Kışla (Barracks) | 40 | Kara birliklerini eğit |
| Tersane (Shipyard) | 40 | Deniz birliklerini inşa et |
| Şehir Duvarı (Town Wall) | 40 | Savunma bonusu |
| Gözetleme Kulesi (Hideout) | 32 | Casusluk, gizli birlikleri sakla |

**Bilim ve Diplomasi:**
| Bina | Maks Seviye | İşlev |
|------|-------------|-------|
| Akademi (Academy) | 40 | Araştırma puanı üret |
| Elçilik (Embassy) | 40 | İttifak kur/katıl, diplomasi |
| Liman (Trading Port) | 40 | Ticaret, kargo gemisi üretimi |
| Pazar Yeri (Trading Post) | — | Oyuncular arası kaynak ticareti |

### 2.4 Bina İnşaat Mekanizması
- Her bina seviye yükseltmesi zaman ve kaynak gerektirir
- Maliyet formülü: `base_cost × (1.5 ^ seviye)`
- Süre formülü: `base_time × (1.2 ^ seviye)` (dakika cinsinden)
- Aynı anda yalnızca 1 bina inşaatı (premium ile 2)
- İnşaat tamamlama: pg_cron + Edge Function kontrol eder

---

## Faz 3 — Araştırma Sistemi (Hafta 5-6)

### 3.1 Araştırma Dalları

```
4 Ana Dal:
├── Denizcilik (Seafaring)
│   ├── Gemi İnşası
│   ├── Haritacılık
│   ├── Lojistik
│   └── İleri Tersane
├── Ekonomi (Economy)
│   ├── Muhasebecilik
│   ├── Kağıt Para
│   ├── Ticaret Yolları
│   └── Vergi Reformu
├── Bilim (Science)
│   ├── Matematik
│   ├── Fizik
│   ├── Kimya
│   └── Optik
└── Askeri (Military)
    ├── Kılıç Dövme
    ├── Zırh Yapımı
    ├── Mühendislik
    └── Top Dökümü
```

### 3.2 Araştırma Mekanizması
- Akademi binası araştırma puanı üretir (saatlik)
- Her araştırma belirli miktarda puan gerektirir
- Araştırma puanı birikince → otomatik tamamla veya kullanıcı başlatsın
- Ön koşul sistemi: bazı araştırmalar diğerlerine bağlı

---

## Faz 4 — Harita Sistemi (Hafta 6-8)

### 4.1 Dünya Haritası
- Ada bazlı dünya haritası (grid sistemi)
- Her ada 16-17 şehir yeri içerir
- Her adada 1 ahşap kaynağı + 1 lüks kaynak (mermer/kristal/kükürt)
- Flame engine ile scrollable/zoomable 2D harita

### 4.2 Ada Görünümü
- Adadaki tüm şehirler listelenmiş
- Kaynak toplama alanları görünür
- Diğer oyuncuların şehirleri tıklanabilir (bilgi, saldırı, ticaret)

### 4.3 Şehir Görünümü
- Grid tabanlı bina yerleşimi
- Binaların seviyesine göre görsel değişim
- Animasyonlu inşaat, duman efektleri (Flame)
- Drag & drop bina yerleştirme (ileri faz)

### 4.4 Harita Veri Yapısı
```sql
-- Adalar tablosu
CREATE TABLE islands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  x INT NOT NULL,
  y INT NOT NULL,
  wood_level INT DEFAULT 1,
  luxury_resource TEXT CHECK (luxury_resource IN ('marble', 'crystal', 'sulfur')),
  luxury_level INT DEFAULT 1,
  miracle TEXT, -- ada mucizesi
  UNIQUE(x, y)
);

-- Şehirler tablosu
CREATE TABLE cities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  player_id UUID REFERENCES auth.users(id),
  island_id UUID REFERENCES islands(id),
  island_slot INT NOT NULL, -- 1-17 arası
  name TEXT NOT NULL,
  population INT DEFAULT 40,
  happiness INT DEFAULT 100,
  wood NUMERIC DEFAULT 500,
  marble NUMERIC DEFAULT 0,
  crystal NUMERIC DEFAULT 0,
  sulfur NUMERIC DEFAULT 0,
  gold NUMERIC DEFAULT 500,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_resource_update TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(island_id, island_slot)
);
```

---

## Faz 5 — Askeri Sistem (Hafta 8-11)

### 5.1 Kara Birimleri
| Birim | Sınıf | Gereksinim |
|-------|-------|------------|
| Hoplite | Hafif Piyade | Kışla 1 |
| Phalanx | Ağır Piyade | Kışla 4, Araştırma |
| Okçu (Archer) | Menzilli | Kışla 6 |
| Süvari (Cavalry) | Atlı | Kışla 10, Araştırma |
| Mancınık (Catapult) | Kuşatma | Kışla 16, Araştırma |
| Havan (Mortar) | Kuşatma | Kışla 22, Araştırma |
| Doktor (Medic) | Destek | Kışla 8 |
| Aşçı (Cook) | Destek | Kışla 12 |

### 5.2 Deniz Birimleri
| Birim | Sınıf | Gereksinim |
|-------|-------|------------|
| Kargo Gemisi | Taşıma | Liman 1 |
| Ram Ship | Saldırı | Tersane 4 |
| Catapult Ship | Menzilli | Tersane 10 |
| Mortar Ship | Ağır | Tersane 16 |
| Diving Boat | Gizli | Tersane 22 |

### 5.3 Savaş Sistemi
- **Tur bazlı** savaş hesaplaması (backend'de)
- Savaş başladığında Edge Function ile hesaplama
- Saldırı → deniz savaşı (varsa) → kara savaşı → yağma/işgal
- Savunma bonusu: şehir duvarı + garnizon
- Savaş raporu her iki tarafa da gönderilir (Realtime notification)

### 5.4 Savaş Hesaplama Formülü (Basitleştirilmiş)
```
Saldırı Gücü = Σ(birim_sayısı × birim_saldırı × (1 + araştırma_bonusu))
Savunma Gücü = Σ(birim_sayısı × birim_savunma × (1 + duvar_bonusu + araştırma_bonusu))

Kayıp Oranı:
- Kazanan: %10-30 kayıp (güç farkına göre)
- Kaybeden: %60-100 kayıp
```

---

## Faz 6 — Ticaret ve Diplomasi (Hafta 11-13)

### 6.1 Ticaret Sistemi
- Oyuncular arası kaynak ticareti
- Kargo gemisi ile taşıma (mesafeye göre süre)
- Pazar yeri: alış/satış emirleri (order book)
- Ticaret yolları: sık kullanılan rotaları kaydet

### 6.2 İttifak Sistemi
- İttifak kurma/katılma (Elçilik binası gerekli)
- İttifak rolleri: Lider, General, Diplomat, Üye
- İttifak içi mesajlaşma (Supabase Realtime)
- Savaş ilan etme, NAP (saldırmazlık) anlaşması

### 6.3 Mesajlaşma
- Oyuncu-oyuncu özel mesaj
- İttifak forum/sohbet
- Supabase Realtime ile anlık bildirim

---

## Faz 7 — Sıralama ve Endgame (Hafta 13-15)

### 7.1 Sıralama Tabloları
- Toplam puan (bina seviyeleri + araştırma + askeri güç)
- Asker sıralaması
- Denizci sıralaması
- İttifak sıralaması
- Ada bazlı sıralama

### 7.2 Puan Hesaplama
```
Toplam Puan = Bina_Puanı + Araştırma_Puanı + Askeri_Puan + Altın_Puanı
- Bina Puanı: Her bina seviyesi için artan puanlar
- Araştırma Puanı: Tamamlanan araştırmalar
- Askeri Puan: Aktif asker + gemi sayısı
```

---

## Veritabanı Şeması (ER Diyagramı)

Temel tablolar:

```
players          → auth.users üzerine profil
islands          → dünya haritası grid
cities           → oyuncu şehirleri
buildings        → şehirlerdeki binalar (bina_tipi, seviye)
construction_queue → inşaat kuyruğu (bina, başlangıç, bitiş zamanı)
researches       → tamamlanan araştırmalar
research_queue   → devam eden araştırmalar
military_units   → şehirlerdeki askeri birimler
training_queue   → eğitimdeki birimler
troop_movements  → hareket eden ordular (saldırı, destek, dönüş)
trade_offers     → ticaret teklifleri
trade_routes     → aktif taşımalar
alliances        → ittifaklar
alliance_members → ittifak üyeleri (oyuncu, rol)
messages         → oyuncu mesajları
battle_reports   → savaş raporları
```

---

## Supabase Mimari Detayları

### Realtime Kullanımı
| Kanal | Tür | Kullanım |
|-------|-----|----------|
| `city:{city_id}` | Postgres Changes | Kaynak değişiklikleri, bina tamamlama |
| `player:{player_id}` | Broadcast | Savaş bildirimleri, mesajlar |
| `alliance:{alliance_id}` | Broadcast | İttifak sohbet, savaş uyarıları |
| `island:{island_id}` | Presence | Adada aktif oyuncular |

### Edge Functions
| Function | Tetikleyici | İşlev |
|----------|-------------|-------|
| `tick-resources` | pg_cron (5dk) | Tüm şehirlerin kaynaklarını güncelle |
| `tick-construction` | pg_cron (1dk) | Tamamlanan inşaatları kontrol et |
| `tick-research` | pg_cron (1dk) | Tamamlanan araştırmaları kontrol et |
| `tick-training` | pg_cron (1dk) | Tamamlanan eğitimleri kontrol et |
| `tick-movements` | pg_cron (1dk) | Varan orduları, ticaretleri kontrol et |
| `calculate-battle` | Ordu varışı | Savaş hesaplaması yap |
| `calculate-ranking` | pg_cron (1saat) | Sıralama tablolarını güncelle |

### RLS (Row Level Security) Politikaları
```sql
-- Oyuncu sadece kendi şehirlerini görebilir (detaylı)
CREATE POLICY "own_cities" ON cities
  FOR ALL USING (player_id = auth.uid());

-- Diğer oyuncuların şehirlerini sınırlı görebilir (isim, ada, seviye)
CREATE POLICY "public_city_info" ON cities
  FOR SELECT USING (true); -- view ile sınırlı sütunlar

-- Mesajları sadece alıcı/gönderici görebilir
CREATE POLICY "own_messages" ON messages
  FOR SELECT USING (
    sender_id = auth.uid() OR receiver_id = auth.uid()
  );
```

---

## Güvenlik ve Anti-Cheat

| Kural | Uygulama |
|-------|----------|
| Kaynak hesaplaması sunucuda | Edge Function ile, client sadece tetikler |
| Savaş hesaplaması sunucuda | Client savaş başlatır, sonuç backend'den gelir |
| Rate limiting | Supabase rate limits + özel kontroller |
| İnşaat doğrulama | Edge Function: yeterli kaynak var mı, ön koşullar sağlanıyor mu |
| Zaman manipülasyonu engeli | Tüm zamanlar server-side (NOW()) |

---

## Geliştirme Takvimi (Özet)

| Faz | Hafta | İçerik | Öncelik |
|-----|-------|--------|---------|
| **1** | 1-2 | Altyapı, Auth, Flutter iskeleti | 🔴 Kritik |
| **2** | 3-5 | Kaynak sistemi, binalar, şehir UI | 🔴 Kritik |
| **3** | 5-6 | Araştırma ağacı | 🟡 Yüksek |
| **4** | 6-8 | Harita sistemi (ada + dünya) | 🔴 Kritik |
| **5** | 8-11 | Askeri sistem, savaş | 🟡 Yüksek |
| **6** | 11-13 | Ticaret, ittifak, diplomasi | 🟡 Yüksek |
| **7** | 13-15 | Sıralama, polish, optimizasyon | 🟢 Normal |
| **8** | 15-17 | Test, bug fix, beta | 🟢 Normal |

---

## MVP (Minimum Viable Product) Kapsamı

İlk çalışır versiyonda olması gerekenler:
1. ✅ Kayıt/giriş
2. ✅ 1 şehir oluşturma
3. ✅ 5-6 temel bina (Belediye, Depo, Kışla, Akademi, Liman, Duvar)
4. ✅ Ahşap + altın kaynağı
5. ✅ 2-3 temel asker birimi
6. ✅ Basit ada haritası
7. ✅ Başka oyunculara saldırma
8. ✅ Temel ticaret

---

## İlk Adım: Ne ile Başlayalım?

1. **Supabase projesi oluştur** → Tablo şemasını kur
2. **Flutter projesi oluştur** → Auth flow + ana navigasyon
3. **Şehir ekranı** → Bina grid, kaynak göstergesi
4. **Kaynak tick sistemi** → pg_cron + Edge Function

Bu plan onaylanırsa, Faz 1'den başlayarak adım adım implemente edebiliriz.
