# Session handoff

## Current slice
A single-room prototype with arrow and tap-to-move input, exact tap selection and a range indicator. Placeholder shapes only.

## Next gate
Verify startup in Godot 4.7.2 headless, then test touch on Android. Import a small, verified TAMU data sample with stable IDs. Wire Rubonnek Inventory Manager to a bag and chest, then write a versioned save with CodingQuests Save System and replay inventory/quest state on load.

## Selected integrations, not installed
Rubonnek Quest Manager for quest progress; CodingQuests State Machine for NPC behavior; ClutteredCode 2D hit/hurt/health; Survival Core Lite clock and survival stats only; GdUnit4 for tests. Evaluate Gohud, Interaction Feedback, and What’s Code Mini Map on device. Better Tile Editor and SpriteFrames Batch Importer are authoring tools.
Settings + Menus is the settings candidate. No Maaack’s, Fantasy Map Generator, duplicate inventory, or separate loot plugin. Crafting and simple placement stay in TAMU until a suitable extension is verified.

## EşRota ana entegrasyon planı

Bu dosya ana plan, brif ve Markdown teslim raporlarının ortak kaynağıdır. Avenox görevi `tamu-topdown-bootstrap` tek kanonik görevdir (plan hazırlanırken revizyon 2); bu dosya ikinci görev sistemi değildir.

**Sıralama:** Kullanıcı aynı ChatGPT projesinde çalışma sohbetlerini tek tek açar. Tek aktif yazıcı, yalnız `TheOsmanYILDIRIM/TAMU-Topdown/main`. Yeni dal/PR, force, reset veya geçmiş değişikliği yok. Bir sonraki sohbet önceki teslimi koordinatör geri okuyup kabul etmeden kod yazmaz. Koordinatör kullanıcı dönüşüyle çalışır; otomatik izleme veya bildirim yok.

**Ortak uygulama kuralları:** Başlarken main HEAD, AGENTS.md, README.md, bu dosya ve mevcut Beyin görevi okunur. Yalnız aktif entegrasyon ve atanmış yollar yazılır; sonraki dalga açılırken somut yollar güncel kaynakla belirlenir. Eklenti kaynak/ref ve lisansı kaydedilir; örnek sahne, demo görseli ve eski TAMU kodu alınmaz. Ortak yapılandırma için tek yazıcı; yazmadan önce HEAD/ilgili blob kontrolü, çoklu dosyada beklenen HEAD ile non-force güncelleme, yazdıktan sonra commit ve içerik geri okuması. Çakışmada veya başarısız kabul testinde dur ve engeli raporla. Godot 4.7.2, tipli GDScript, Compatibility ve Android hedefi korunur.

| Sohbet | Entegrasyon | Önce doğrulanacak | Kabul |
|---|---|---|---|
| SOHBET-01 | GdUnit4 ve başlangıç testi | — | Godot 4.7.2 headless açılış; hareket ve doğru nesneyi seçme testi. GdUnit4 geliştirme/CI, APK dışı. |
| SOHBET-02 | Rubonnek Inventory Manager | 01 | Doğrulanmış TAMU eşya kimlikleriyle çanta + sandık; dolu hedefte kayıp yok, kısmi aktarım doğru. |
| SOHBET-03 | CodingQuests Save System | 02 | Sürümlü state.json; oyuncu, çanta, sandık ve alınmış dünya nesnesi geri yüklenir. Kesintide önceki sağlam kayıt korunur; meta.json yalnız özet. |
| SOHBET-04 | Rubonnek Quest Manager | 03 | Yarım hedef yüklenir; başarısız toplama sayılmaz; ödül ikinci kez verilmez. |
| SOHBET-05 | ClutteredCode 2D savaş | 04 | Yalnız Basic 2D hit/hurt ve tek can bileşeni. İsabet, ıskalama, ölüm testleri. |
| SOHBET-06 | CodingQuests State Machine | 05 | Yalnız FSM çekirdeği: gezin/kaç ve takip/hazırlan/saldır/toparlan; hatalı geçişler doğrulanır. Demo taşınmaz. |
| SOHBET-07 | Survival Core Lite | 06 | Sadece gün/gece ve açlık-susuzluk; açlık hasarı mevcut cana gider. İkinci envanter/üretim yok. |
| SOHBET-08 | Interaction Feedback | 07 | Sadece görsel vurgu. Dokunulan hedef seçilir; menzil kuralları değişmez. |
| SOHBET-09 | Gohud | 08 | Android hotbar ve çanta; Rubonnek tek veri sahibi. Dokunma, güvenli alan, geri tuşu; blur kapalı. Uygun değilse Theme Assist alternatif, ikisi birden değil. |
| SOHBET-10 | Settings + Menus | 09 | Duraklatma, ses ve kalıcı ayarlar; HUD çakışmaz, Android’de masaüstü seçenekleri yok. |
| SOHBET-11 | What’s Code Mini Map | 10 | Oyuncu dünya koordinatıyla izlenir. Gizliyken çizim yok; Android’de açık/kapalı kare süresi ölçülür. |
| SOHBET-12 | Better Tile Editor | 11 | Godot yerel TileSet/TileMapLayer çıktısı; editör aracı, runtime bağımlılığı yok. |
| SOHBET-13 | SpriteFrames Batch Importer | 12 | Yeni sprite üzerinde yön/kare eşleşmesi ve çıktı doğrulanır; editör aracı, runtime bağımlılığı yok. |

Plan dışı: Maaack’s ve Fantasy Map Generator alınmaz. Üretim, basit inşa ve ganimet için paket kurulmaz. Planwren, Chris Grid Placement, Text Database ve Map & Quest Authoring ancak ayrıca ihtiyaç doğrulanırsa değerlendirilir. Ste’s Project yalnız referans.

### Dalga 1 ön kontrolü

<!-- ESROTA_CONTRACT_BEGIN -->
```json
{
  "schema_version": 1,
  "project": {
    "name": "TAMU-Topdown",
    "canonical_location": "https://github.com/TheOsmanYILDIRIM/TAMU-Topdown",
    "observed_revision": "c28fd70ffd33fd6194adfb219973d8dd509e5ade",
    "existing_work_summary": "Tek oda prototipi; hiçbir eklenti kurulu veya runtime testi doğrulanmış değil."
  },
  "coordination": {
    "coordinator_id": "SOHBET-K",
    "persistence_required": true,
    "channel_mode": "existing_record",
    "channel_ref": "TheOsmanYILDIRIM/TAMU-Topdown@main:SESSION_HANDOFF.md",
    "channel_verified": true,
    "user_approved_new_record": false,
    "handoff_method": "coordinator_rechecks_on_user_return",
    "auto_notification_claimed": false,
    "report_format": "markdown",
    "execution_mode": "implementation",
    "dispatch_state": "new",
    "conflict_resolution": "merged_single_writer",
    "merge_rationale": "Her dalgada tek aktif main yazıcısı; ortak project.godot ve sahne sözleşmesi sonraki dalgaya devredilir.",
    "minimum_viable_agents": 1,
    "shared_runtime_coupled": true
  },
  "agents": [
    {
      "id": "SOHBET-01",
      "focus": "GdUnit4 ve başlangıç testi",
      "code_access": "write",
      "report": {
        "target": "TheOsmanYILDIRIM/TAMU-Topdown@main:SESSION_HANDOFF.md#rapor-01",
        "write_scope": "report_only",
        "revision_guard": "single_writer",
        "readback_method": "provider_reopen",
        "markdown_template": "assets/agent-report.md"
      },
      "write_paths": [
        "addons/gdUnit4/",
        "tests/",
        "project.godot",
        "SESSION_HANDOFF.md"
      ],
      "depends_on": [],
      "wave": 1
    }
  ]
}
```
<!-- ESROTA_CONTRACT_END -->

### SOHBET-01 brifi

[SOHBET-01 | GdUnit4 ve başlangıç testi] — Her mesajına bu başlıkla başla.
Yalnız TAMU-Topdown main üzerinde çalış, yeni dal açma. Bu dosyadaki ortak kuralları uygula. Godot 4.7.2 için GdUnit4 sürümünü kaynak ve lisansıyla doğrula, yalnız gerekli geliştirme dosyalarını ekle. Yukarıdaki sözleşme dışındaki dosyaları değiştirme. Headless açılış, hareket ve yan yana nesnelerden dokunulanı seçme testini çalıştır. Godot/çalıştırıcı erişimi yoksa bunu blocked/unverified bildir; geçilmiş test veya Android sonucu varsayma. Rapor hedefi `TheOsmanYILDIRIM/TAMU-Topdown@main:SESSION_HANDOFF.md#rapor-01`; yalnız kendi bölümünü yaz, GitHub'dan yeniden açıp blob SHA ile doğrula (provider_reopen). Teslimde kod commit'i ve rapor bağlantısını kullanıcıya ver. Yeni Beyin görevi açma.

## Teslim raporları

Her bölümde: durum (review_requested/blocked/unverified), benzersiz event_id, UTC (bilinmiyorsa unknown), başlangıç HEAD, yazılan yollar, kod commit'i, eklenti sürümü/lisansı, gerçek test komutları ve sonuçları, CI/Android ayrı, açık iş/engel ve sonraki adım. Raporun geri okuma SHA'sını teslim mesajına koy. Koordinatör başlık ve commit'ten geri okur; rapor tek başına kabul kanıtı değildir.

### Rapor 01

- **Durum:** `review_requested` — GitHub Actions kabul testleri geçti. Koordinatör onayı bekleniyor.
- **Olay:** `tamu-topdown-sohbet01-ci-44152103521` · UTC `2026-11-17T18:50:39Z` (CI tamamlanma zamanı).
- **Başlangıç HEAD:** `c06d76e1bb1f713076179fec4513005cb1fe49c6`. **Test edilen kod:** [`dff1afce330f73fd6535c7886e667f3b9f0cd270`](https://github.com/TheOsmanYILDIRIM/TAMU-Topdown/commit/dff1afce330f73fd6535c7886e667f3b9f0cd270). Önceki engel raporu ilk commit'te korunuyor.
- **Yollar:** `.github/workflows/godot-tests.yml`, `tests/prototype_test.gd`, `tests/.gdignore`. Oyun kaynakları değişmedi; yeni dal/PR yok.
- **Eklenti:** [GdUnit4 v6.2.0, sabit kaynak](https://github.com/godot-gdunit-labs/gdUnit4/tree/d18770221c2df4a3c991a42fdce7907df40eea75), MIT. Yalnız CI'nın geçici proje kopyasına kuruldu; oyun checkout'una eklenmedi.
- **CI kararı ve gerekçesi:** Kullanıcı kararıyla kurulum ve kabul testleri sohbetin yerel ortamında değil, GitHub Actions üzerinde yürütülür. İlk teslimde Godot 4.7.2 çalıştırıcısı doğrulanamadığı için test sonucu alınamamıştı. Workflow, SHA-512 ile doğrulanan aynı motoru ve commit’e sabitlenmiş GdUnit4 sürümünü kullanır. Böylece testler tekrarlanabilir, sonuçlar ilgili commit ve Actions günlükleriyle izlenebilir; GdUnit4 oyun projesine eklenmeden CI’da kalır.
- **Gerçek CI:** [44152103521](https://github.com/TheOsmanYILDIRIM/TAMU-Topdown/actions/runs/44152103521), başarılı. SHA-512 doğrulandı; motor `4.7.2.stable.official.ed1daf0bf`. `godot --headless --path . --editor --import` ve `godot --headless --path . --quit-after 10` geçti.
- **GdUnit4:** `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/prototype_test.gd --ignoreHeadlessMode` → 2/2, 0 hata, 0 atlanan test. Zemine sentetik dokunuşla hareket ve sandık/ağaç/boş alan ayrımı JUnit ile doğrulandı.
- **Doğrulanmamış:** Android cihaz testi ve APK içeriği denetimi yapılmadı; CI bu çalıştırmada APK üretmedi. SOHBET-02 için koordinatör teslimi yeniden okumalı.

### Rapor 02

SOHBET-02 | Rubonnek Inventory Manager — önceki kabulü bekliyor.

### Rapor 03

SOHBET-03 | CodingQuests Save System — önceki kabulü bekliyor.

### Rapor 04

SOHBET-04 | Rubonnek Quest Manager — önceki kabulü bekliyor.

### Rapor 05

SOHBET-05 | ClutteredCode 2D savaş — önceki kabulü bekliyor.

### Rapor 06

SOHBET-06 | CodingQuests State Machine — önceki kabulü bekliyor.

### Rapor 07

SOHBET-07 | Survival Core Lite — önceki kabulü bekliyor.

### Rapor 08

SOHBET-08 | Interaction Feedback — önceki kabulü bekliyor.

### Rapor 09

SOHBET-09 | Gohud — önceki kabulü bekliyor.

### Rapor 10

SOHBET-10 | Settings + Menus — önceki kabulü bekliyor.

### Rapor 11

SOHBET-11 | What’s Code Mini Map — önceki kabulü bekliyor.

### Rapor 12

SOHBET-12 | Better Tile Editor — önceki kabulü bekliyor.

### Rapor 13

SOHBET-13 | SpriteFrames Batch Importer — önceki kabulü bekliyor.
