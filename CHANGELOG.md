# Changelog

## v0.14.0 (2026-08-31)

### Highlights

- Map screen search and filter redesigned to match the Contacts/Channels pattern; overlapping node labels are now automatically pushed apart instead of stacking on top of each other (#116)

### Features

- Map: node-label collision resolver keeps clustered repeaters/contacts legible when several are close together (#116)

### Fixes

- Map: node-label bubbles size to their content with correct centering and clipping; zoom and clustering thresholds tuned (#116)

## v0.13.0 (2026-08-30)

### Highlights

- USB firmware flasher: flash MeshCore-compatible boards directly from the app over USB, with a local-first firmware catalog (board → ROM type → version), live download/flash progress, retry, and search (#110) (#113)
- Companion-connect screens (BLE/USB/TCP) redesigned with a unified shared port-stepper and consistent app-bar treatment (#113)
- Contact and channel cards brought to full visual parity: typography, spacing, badges, favorite toggle, overflow handling, and a shared selection-sheet pattern for sort/filter menus (#113)

### Features

- USB flasher: SLIP framing and esptool ROM-loader protocol (SYNC, SPI attach, flash write), DTR/RTS bootloader reset, and a dedicated Flasher About screen (#110)
- Per-conversation translation language override and mute, with channel-card parity for the new controls (#113)
- App-bar leading/trailing icons unified to the 48×48 circular-accent pattern across 14+ screens (#113)

### Fixes

- Contact cards: right-aligned favorite star toggle, ellipsis instead of a hard clip on overflowing names, unified typography and badge spacing with channels (#113)
- Web build: implement the `setDtr`/`setRts` USB serial signals on the Web Serial backend so the ESP flash transport compiles for web

## v0.12.0 (2026-08-25)

### Highlights

- New app icon and brand identity: a forest-green MeshNomad lockup replaces the placeholder icon across every platform (#105)
- meshnomad.org gets a branded landing page: hero section, wordmark and Material theme matched to the app's identity (#104)

### Features

- App icon: hand-built SVG masters (mark, adaptive foreground, brand lockup) with a one-command regeneration pipeline covering Android (adaptive + monochrome), iOS, macOS, Windows and web (#105)
- About screen shows the brand lockup: mark tinted with the active theme, dual-weight "meshnomad" wordmark (#105)
- meshnomad.org: branded hero section, dual-weight wordmark in the site header and navigation drawer, forest color palette (#104)

### Fixes

- About screen: version line no longer shows the raw platform build number, which Android's per-architecture packaging can mangle into a value that reads like a year (#107)
- About screen: app description and license footer text are centered; the lockup and wordmark pick up a drop shadow when the active style has card shadows enabled (#107)

## v0.11.0 (2026-08-23)

### Highlights

- Settings overhaul: every fixed-choice picker (sheets, dropdowns, segmented buttons) replaced with a shared -/+ value stepper that follows the app-wide button border style (#100)
- About screen with build provenance: commit/branch/build-time/source stamped into every APK (local builds via `tool/build_apk.sh`, CI builds via the release workflow) (#100)

### Features

- About: version with build number and copy-to-clipboard, project links (meshnomad.org, docs in the app language, releases, source, issues), open-source licenses page (#100)

- Packet stats: wider analysis windows (15/30/60 min, 24 h, 7 days, 2 weeks, Session) with a floating window stepper (#100)

- Message history limit gains a 2000 step (#100)

### Fixes

- Button border (none/solid/dotted) styles only the active button of a selection group; action buttons (Save, Download model) are always borderless (#98) (#100)

- Auto route rotation, Radio settings, Radio stats, Contact settings, Privacy settings and Node name moved from popups to dedicated card screens (#100)

- Battery type relocated to Node settings (LiPo/NMC/LiFePO4); path hash mode inline stepper limited to the firmware-supported 1/2/3-byte modes (#100)

- Leading row icons tinted with the theme primary across Settings; centered Settings title; notification row text colors restored (#100)

- Contacts: draggable group-management sheet, full-width search, group type filter, tinted filter icon (#98)

- Blue profile secondary accent defaults to cyan #06B6D4; CYR2LAT section layout with description and icon-circle actions; shortened selector labels (EN/PL) (#100)

- Localization: all 38 previously missing Polish keys filled (#100)

## v0.10.0 (2026-08-22)

### Highlights

- Rebrand: MeshCore Open -> MeshNomad — new app identity, `com.meshnomad.app` application ID across all platforms (#65)

### Features

- Redesign repeater CLI command help as a draggable drawer with param popup (#81)

- Implement GET_STATS CORE/PACKETS subtypes (#70)

- Contacts status badge row + UI polish batch (#67)

- Implement v117 advert-path diagnostics and flood-scope default (#51) (#61)

- Wire up device-time sync and add logout/has-connection commands (#60)

- Layout-theme + color-profile engine (Green/Blue, accent-following chat/chrome) (#31)

- Custom-style reactivity + spacing/radius/card editor sections (#25)

- Give MeshCard a floating shadow style app-wide (#22)

- Add widget-preview spike for DottedSeparator

- Lightness slider and hex example chips in the style editor color picker

- Per-brightness editing switch in custom style editor

- Per-brightness color overrides model with legacy migration

- Light-variant base tokens and layer derivers for custom style

- Radio stats band chart with SNR strip and airtime duty-cycle budget

- Dotted rule above bubble footer and route map popup in channel chat

- Interactive indicator popups with one shared dialog pattern

- Transport indicator, separator rhythm and one main app bar pattern

- Unify app bar indicators and enrich nearby repeaters dialog

- Move open-source link to About row and scope editor icon to Custom style

- Localized style editor with map/LOS sections and per-field reset

- Route list tiles, chrome and large titles through editable text roles

- Derive color variants and ColorScheme from base tokens in custom style

- Add flutter_driver entry point for MCP live-driving

- Wire flutter_skill agent-testing binding in debug builds

- Add custom style editor screen

- Add editable custom style model and persistence

- Enable app-wide text selection via SelectionArea

- Add style picker to app settings

- Add style registry infrastructure (default style unchanged)

### Bug Fixes

- Match switch/slider fills to the tinted-button track pattern (#93)

- Make Theme/Style chip buttons respect the Buttons section's radius and border (#92)

- Relocate Custom Style entry and Card shadow toggle within App Settings (#92)

- Unify Node/Location/About settings into dedicated screens, relocate GPX export (#92)

- Wrap the group-dropdown "All groups" label to prevent overflow (#91)

- Encrypt repeater passwords at rest (#64)

- Scope path_history to the connected device (#45) (#62)

- Verify Ed25519 signatures on received adverts (#59)

- Route RouteChip's hop-count label through l10n (closes #36) (#42)

- Convert SerialPortError to StateError on desktop USB write

- Disable auto-enabled flutter_skill indicators and restore debug banner

- Keep the style editor reset icon visible but disabled when there's nothing to reset

- Build custom style light variant from light base tokens

- Mirror the app bar's right margin to the title's left inset

- Raise quick switch bar height so pill, labels and badge fit

- Keep color picker hex field clear of system nav bar

- Eliminate idle-CPU busy-loop on BLE reconnect and USB transport (#16)

- Scope text selection to visible content and enable copying in style editor

- Uniform node label font size and text selection in node details sheet

- Simplify contacts_ping label to 'Ping' in Polish

- Give app-wide SelectionArea a reachable Overlay ancestor

- Debounce PathHistoryService persistence to stop BLE sync freeze

- Correct PL telemetry battery unit typo (W to V)

- Repair broken path_trace_test.dart and clear repo-wide formatting drift

### Performance

- Split release APK per-ABI to shrink per-device downloads (#82)

- Avoid O(n^2) unread lookups and switch contact sync to incremental

### Refactoring

- Rename color tokens blue*/magenta* to primary*/secondary* with prefs migration

- Migrate fontSize literals to textTheme roles + add mono size tokens

- Switch selectable text widgets to SelectableText, fix glibc/flserial build workaround

- Migrate repeater/debug/misc screens to MeshTokens

- Migrate chat/contacts/channels screens to MeshTokens

- Migrate map/LOS screens to MeshTokens

### CI/CD

- GitHub Release pipeline (signed APK+AAB, git-cliff notes, Cloudflare deferral) (#80)

- Add signed Android App Bundle release job (#66)

- Pin Flutter version across workflows (#30)

- Drop --no-pub from android build so plugin registrant is regenerated release-aware

- Skip Flutter build/analyze workflows for docs-only changes

- Bump GitHub Actions to their Node 24 runtime releases

### Documentation

- Document UI testing layers (golden, integration, patrol, mcp)

- Document the style picker added by the theme system

### Testing

- Add integration test automating custom style gate checklist

- Add golden test for custom style editor screen layout

- Add golden test for custom style override rendering

- Add golden tests pinning default style text roles

- Add alchemist golden test infrastructure
