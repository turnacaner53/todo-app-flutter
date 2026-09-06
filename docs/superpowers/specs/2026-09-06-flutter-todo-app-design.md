# Todo App Flutter v2 — Tasarım Spec'i

Tarih: 2026-09-06 · Durum: Onaylandı (paket listesi + mimari kullanıcı onayından geçti)
Referans proje: `D:\_PROJECTS\qwen3.8-test-project\todo-app` (Next.js, local-first)

## 1. Amaç

Next.js todo-app'ın Flutter mobil (Android + iOS) yeniden yazımı. Local-first, backend yok:
görev listeleri, zengin metinli notlar, ortak çöp kutusu, liste/not başına renk,
drag-reorder ve light/dark/system tema — hepsi cihazda SQLite'ta.

UI metinleri İngilizce. Platform: Android + iOS (web/desktop hedef yok).

## 2. Teknoloji Yığını

Doğrulama kaynağı: fluttergems.dev bakım durumu + pub.dev son yayın tarihi (2026-09-06).

| Paket | Sürüm pin | Amaç | Not |
|---|---|---|---|
| flutter_riverpod / riverpod_annotation | ^3.4.3 | State + DI | fluttergems: Good, 1.9M+/ay |
| riverpod_generator (dev) | ^4.0.9 | `@riverpod` kod üretimi | |
| riverpod_lint + custom_lint (dev) | ^3.1.9 / ^0.8.1 | Statik kurallar | |
| drift / drift_dev (dev) | ^2.34.4 / ^2.34.6 | Tip-güvenli SQLite, reactive stream | Dexie/IndexedDB karşılığı |
| drift_flutter | ^0.3.1 | Platform DB kurulumu | sqlite3_flutter_libs'i kendisi çeker |
| go_router | ^18.0.1 | Navigasyon | Flutter ekibi, resmi |
| flutter_quill | ^11.5.1 | Not WYSIWYG editörü | Tiptap karşılığı; delta JSON saklanır |
| flutter_reorderable_grid_view | ^5.7.0 | Dashboard drag-reorder grid | |
| shared_preferences | ^2.5.5 | Tema tercihi kalıcılığı | |
| google_fonts | ^8.2.1 | Inter tipografisi | |
| flutter_colorpicker | ^1.1.0 | Custom renk seçici | opsiyonel katman, palet yeterli olsa da |
| uuid | ^4.6.0 | id üretimi | |
| build_runner (dev) | ^2.16.1 | Kod üretimi | |
| very_good_analysis (dev) | ^11.0.0 | Lint kuralları | |

Bilinçli olarak yok: freezed/json_serializable (drift satır sınıflarını üretiyor; ekstra
codegen katmanı gerekmiyor), bloc, get_it (Riverpod DI'ı üstleniyor), Hive/Isar (bakım
durumu zayıf/ölü).

## 3. Mimari

Katmanlar: **DB (drift DAO) → Repository → Riverpod Notifier/Provider → Widget.**
Feature-first klasörleme; her feature kendi screen/widget/provider dosyalarını tutar,
paylaşılan her şey `core/` veya `app/` altında.

```
lib/
├── main.dart                      # ProviderScope + bootstrap (prefs, purge trash)
├── app/
│   ├── app.dart                   # MaterialApp.router, tema wiring
│   ├── router.dart                # GoRouter: /, /list/:id, /note/:id, /trash
│   └── theme/
│       ├── app_theme.dart         # Material 3 light/dark, seed color, Inter
│       └── palette.dart           # 8 renk + tint yardımcıları
├── core/
│   ├── db/
│   │   ├── tables.dart            # drift tablo tanımları
│   │   ├── database.dart          # AppDatabase + DAO'lar
│   │   └── migrations.dart        # schemaVersion/onUpgrade
│   ├── widgets/                   # empty_state, confirm_dialog, color_picker_sheet,
│   │                              # swipe_delete_wrapper, section_header
│   └── utils/                     # id.dart (uuid sarmalayıcı), debounce.dart, time.dart
└── features/
    ├── settings/                  # theme_mode_provider (prefs'e yazar)
    ├── dashboard/                 # dashboard_screen, card grid, reorder handler,
    │                              # unified feed provider, trash FAB
    ├── task_list/                 # list_detail_screen, task_tile, filter, color,
    │                              # task_dao erişim provider'ları
    ├── notes/                     # note_editor_screen (quill), note_card, autosave
    └── trash/                     # trash_screen, restore/hard-delete/empty, retention
```

Kurallar:

- Widget'lar DAO'ya doğrudan bakmaz; her zaman Riverpod provider'ı üzerinden.
- Tüm liste/not/task state'i drift stream'lerinden türetilir (tek kaynak / source of
  truth = DB). UI'da kopya state tutulmaz; `watchAll()` stream'leri Riverpod'a bağlanır.
- Yazma işlemleri Notifier metodlarında: `addTask`, `toggleTask`, `renameTask`,
  `deleteTask`, `reorderTasks`, `setListColor`, ... — hepsi drift transaction'ı içinde.
- `analysis_options.yaml` = very_good_analysis + custom_lint.

## 4. Veri Modeli (SQLite / drift)

```
task_lists   id TEXT PK, title TEXT NOT NULL, color INTEGER NULL (0xAARRGGBB),
             position INTEGER NOT NULL, created_at INTEGER NOT NULL

todos        id TEXT PK, list_id TEXT FK→task_lists ON DELETE CASCADE,
             title TEXT NOT NULL, completed INTEGER NOT NULL DEFAULT 0,
             completed_at INTEGER NULL, position INTEGER NOT NULL,
             created_at INTEGER NOT NULL
             INDEX(list_id)

notes        id TEXT PK, title TEXT NOT NULL, content TEXT NOT NULL (Quill delta JSON),
             color INTEGER NULL, position INTEGER NOT NULL,
             created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL

trash_items  id TEXT PK, kind TEXT NOT NULL ('list'|'task'|'note'),
             payload TEXT NOT NULL (silinen kaydın tam JSON'u),
             deleted_at INTEGER NOT NULL
```

- **Reorder:** basit `position` int; drop'ta etkilenen satırlar transaction içinde reindex edilir.
- **Trash:** tek birleşik tablo (onaylandı). Restore = payload JSON'dan ilgili tabloya insert,
  trash satırını sil. Task restore'unda listesi artık yoksa (liste kalıcı silinmişse) task,
  "Restored tasks" adında yeni bir listeye eklenir; liste/not restore'ta `position` uç noktaya
  eklenir. Liste trash payload'ı listedeki tüm task'ları da içerir (`{"list": ..., "tasks": [...]}`).
- **Retention:** uygulama açılışında ve trash ekranı her yüklendiğinde `deleted_at` > 30 gün
  olan satırlar purge edilir. Kartlarda "N gün kaldı" gösterilir.
- Zamanlar epoch milliseconds (eski app ile aynı karar).

## 5. Ekranlar ve Akışlar

**Dashboard (`/`)**
- Lists + notes birleşik feed'i, 2 sütunlu reorderable grid (uzun bas-sürükle).
- Liste kartı: başlık, ilk 3 task özeti + "N kaldı", renk tint'i.
- Not kartı: başlık + düz-metin önizleme (delta'dan strip, max 4 satır), renk tint'i.
- Top app bar: "New list" ve "New note" aksiyonları + tema toggle (light/dark/system döngüsü).
- FAB: çöp kutusu, live sayı badge'i.
- Karttan swipe (sağa) → trash'a taşır + Undo snackbar.
- Boş durum: illüstrasyon + "Create your first list" CTA.

**Task list detay (`/list/:id`)**
- SliverAppBar: liste adı (tap → inline rename), renk noktası → color sheet (8 palet +
  custom picker + "reset"), progress "x/y done".
- Task ekleme: sabit alt input (SubmittedField tarzı), enter ile ekleme.
- Task satırı: checkbox, title (tap → rename dialog), swipe → trash + Undo.
- ReorderableListView ile drag (handle'lı, uzun basma).
- Filtre: SegmentedButton — All / Active / Done; "Clear completed" menü aksiyonu.

**Not editörü (`/note/:id`)**
- flutter_quill editörü: toolbar H1/H2, bold, italic, underline, boyut, liste.
- Başlık alanı üstte; renk seçici app bar'da.
- Autosave: 300 ms debounce → drift update (`updated_at` yenilenir); ekran kapanınca flush.
- Delta JSON `notes.content`'te saklanır; dashboard önizlemesi delta'dan üretilir.

**Trash (`/trash`)**
- Gruplu: Lists / Notes / Tasks; her satırda restore ve kalıcı sil; app bar'da "Empty".
- Swipe = kalıcı sil (confirm dialog'lu), restore = tek tap.

**Bildirim/uygulama ikonu:** kapsam dışı.

## 6. Tema / Tasarım

- Material 3; `ColorScheme.fromSeed` (seed: indigo-temalı modern mor-mavi), light + dark.
- Google Fonts **Inter** tüm tipografi ölçeğinde.
- Kartlar: 20 px radius, soft elevation, renk seçiliyse %8 tint'li surface.
- Renk paleti (`palette.dart`): eski app'taki 8 renk (red/orange/amber/green/teal/blue/
  purple/pink) ARGB int olarak; custom seçim flutter_colorpicker ile.
- Tema tercihi `shared_preferences`'te `ThemeMode` string'i; system default.
- Animasyonlar: grid reorder'da varsayılan flutter animasyonları, page transition'ler
  Material 3 default; abartılı efekt yok (YAGNI).

## 7. Hata Yönetimi

- DB yazma hataları: Notifier try/catch → SnackBar hata mesajı, state rollback'i drift
  transaction'ı halleder.
- Bilinmeyen trash payload tipi: logla + satırı gizle (crash yok).
- Init sırası bootstrap'ta: WidgetsFlutterBinding → prefs oku → DB aç → purge → runApp.
  Hatalı DB açılışında (bozuk dosya) drift `MigrationStrategy.onError` fallback'i yok;
  v1'de hata ekranı gösterilir (basit, bilinçli).

## 8. Test Stratejisi

- **Unit (DAO):** drift `NativeDatabase.memory()` (sqflite_common_ffi) ile — CRUD,
  reorder reindex, trash payload roundtrip, 30 günlük purge, filter sorguları.
- **Unit (Notifier/provider):** theme_mode persist, undo aksiyonu.
- **Widget:** dashboard boş-durum + kart render; task list tamamlama akışı; not autosave
  debounce (fake timer). Editörün kendisi (quill) widget testine sokulmaz — manual.
- `flutter analyze` (very_good) + `flutter test` CI yerine geçmez ama her milestone'da koşulur.

## 9. Kapsam Dışı (v1)

Arama, etiketler, due date/hatırlatma, çoklu dil, senkronizasyon/export, widget/launcher
ikonları, web/desktop hedefleri, legacy localStorage göç ( Flutter tarafında eski veri yok).

## 10. Milestone Sırası (özet)

1. Scaffold: paketler, very_good lint, M3 tema + palette, go_router iskeleti, boş ekranlar
2. Drift katmanı: şema + DAO'lar + memory-DB testleri
3. Riverpod + Task list feature (CRUD, filter, reorder, renk, undo)
4. Notes feature (quill, autosave, renk, kart önizleme)
5. Dashboard (unified grid, reorder, swipe-to-trash, FAB badge, empty state)
6. Trash (restore/purge/empty/retention) + ayarlar (theme mode)
7. Cila: hata snackbar'ları, boş durumlar, analyze + test yeşil, README
