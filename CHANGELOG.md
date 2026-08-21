# Changelog

## v0.8.0 (2026-08-21)

### Highlights

- Rebrand: MeshCore Open -> MeshNomad — new app identity, `com.meshnomad.app` application ID across all platforms (#65)

### Bug Fixes

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


### Features

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


### Performance

- Avoid O(n^2) unread lookups and switch contact sync to incremental


### Refactoring

- Rename color tokens blue*/magenta* to primary*/secondary* with prefs migration

- Migrate fontSize literals to textTheme roles + add mono size tokens

- Switch selectable text widgets to SelectableText, fix glibc/flserial build workaround

- Migrate repeater/debug/misc screens to MeshTokens

- Migrate chat/contacts/channels screens to MeshTokens

- Migrate map/LOS screens to MeshTokens


### Testing

- Add integration test automating custom style gate checklist

- Add golden test for custom style editor screen layout

- Add golden test for custom style override rendering

- Add golden tests pinning default style text roles

- Add alchemist golden test infrastructure

