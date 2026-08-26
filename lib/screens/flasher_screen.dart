import 'dart:async' show Timer, unawaited;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/esp_flash/esp_flash_protocol.dart';
import '../services/esp_flash/esp_serial_transport.dart';
import '../services/firmware_catalog.dart';
import '../services/usb_serial_service.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/app_bar.dart' show quickAccessMenuItems;
import '../widgets/flasher_version_row.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';
import '../widgets/theme_profile_selector.dart' show SelectableChipButton;
import 'flasher_about_screen.dart';

enum FlasherStep { pickFile, connect, flashing, done, error }

enum _FirmwareSourceKind { meshcore, meshcoreSolo, localFile, customUrl }

/// A board can publish separate firmware images for the same flash offset
/// — a BLE-companion build and a USB-companion build (filename markers
/// `_ble`/`_usb`, e.g. Ebyte_EoRa-S3, Heltec_v3, LilyGo_TBeam_1W). Files
/// with neither marker (repeater/room_server builds, or any board that
/// only ever publishes one companion variant) are `generic` — the common
/// case, and the only one most versions ever have.
enum _FileVariant { ble, usb, generic }

_FileVariant _variantOf(CatalogFile file) {
  final lower = file.name.toLowerCase();
  if (lower.contains('_ble')) return _FileVariant.ble;
  if (lower.contains('_usb')) return _FileVariant.usb;
  return _FileVariant.generic;
}

String _variantLabel(_FileVariant variant) => switch (variant) {
  _FileVariant.ble => 'BLE',
  _FileVariant.usb => 'USB',
  _FileVariant.generic => '',
};

/// Distinct variants present in this version's files, in a stable order
/// (ble, usb, generic) — NOT insertion order, so the same variant always
/// sorts to the same chip position across versions.
List<_FileVariant> _variantsFor(CatalogVersion version) {
  final present = version.files.map(_variantOf).toSet();
  return _FileVariant.values.where(present.contains).toList();
}

/// Flasher wizard: offers four firmware sources (MeshCore, MeshCore-Solo,
/// local file, custom URL) via [FirmwareSource] (task 08), with the flash
/// offset selected per-asset instead of hardcoded (task 09).
class FlasherScreen extends StatefulWidget {
  const FlasherScreen({super.key, FirmwareCatalogService? catalogService})
    : _catalogService = catalogService;

  final FirmwareCatalogService? _catalogService;

  @override
  State<FlasherScreen> createState() => _FlasherScreenState();
}

class _FlasherScreenState extends State<FlasherScreen> {
  FlasherStep _step = FlasherStep.pickFile;
  Uint8List? _firmwareBytes;
  String? _fileName;
  double _progress = 0;
  String? _errorMessage;
  _FirmwareSourceKind _sourceKind = _FirmwareSourceKind.meshcore;
  // No code currently mutates this field — the only site that used to
  // (_selectFile, part of the pre-redesign version picker) was removed.
  // Kept mutable (not final) so Local file / Custom URL retain the *option*
  // of targeting the Full Reset offset in the future; today neither path
  // has any UI to set it away from the Update default, so
  // _confirmAndStartFlashing's `_selectedOffset == catalogOffsetFullReset`
  // branch is effectively dead until such UI exists.
  // ignore: prefer_final_fields
  int _selectedOffset = catalogOffsetUpdate;
  late final FirmwareCatalogService _catalogService;
  FirmwareCatalog? _catalog;
  String? _catalogError;
  bool _refreshingCatalog = false;
  String? _selectedBoard;
  bool _boardListOpen = false;
  CatalogRomType? _selectedRomType;
  final TextEditingController _customUrlController = TextEditingController();
  Timer? _successBannerTimer;
  final Map<String, FlasherActionState> _fileStates = {};
  final Map<String, Uint8List> _downloadedBytes = {};
  final Map<String, _FileVariant> _selectedVariantByTag = {};

  @override
  void initState() {
    super.initState();
    _catalogService = widget._catalogService ?? FirmwareCatalogService();
    // Local-first: reads the on-device copy (or the bundled snapshot on
    // first ever run). Never the network — that is the Refresh button.
    _loadCatalog();
  }

  @override
  void dispose() {
    _successBannerTimer?.cancel();
    _customUrlController.dispose();
    super.dispose();
  }

  CatalogSource? get _activeSource {
    final id = switch (_sourceKind) {
      _FirmwareSourceKind.meshcore => 'meshcore',
      _FirmwareSourceKind.meshcoreSolo => 'meshcore_solo',
      _ => null,
    };
    if (id == null) return null;
    for (final source in _catalog?.sources ?? const <CatalogSource>[]) {
      if (source.id == id) return source;
    }
    return null;
  }

  CatalogBoard? get _activeBoard {
    final name = _selectedBoard;
    if (name == null) return null;
    for (final board in _activeSource?.boards ?? const <CatalogBoard>[]) {
      if (board.name == name) return board;
    }
    return null;
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await _catalogService.loadCatalog();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _catalogError = null;
      });
      _resetSelection();
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogError = e.toString());
    }
  }

  Future<void> _refreshCatalog() async {
    setState(() {
      _refreshingCatalog = true;
      _catalogError = null;
    });
    try {
      final catalog = await _catalogService.refreshCatalog();
      if (!mounted) return;
      setState(() => _catalog = catalog);
      _resetSelection();
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogError = e.toString());
    } finally {
      if (mounted) setState(() => _refreshingCatalog = false);
    }
  }

  /// Re-derives the default selection chain (first board → its first ROM
  /// type → its newest version) for the active source; clears any fetched
  /// firmware since the underlying choice changed.
  void _resetSelection() {
    final source = _activeSource;
    final board = source?.boards.firstOrNull;
    final romType = board?.romTypes.firstOrNull;
    _selectedVariantByTag.clear();
    setState(() {
      _selectedBoard = board?.name;
      _boardListOpen = false;
      _selectedRomType = romType;
      _firmwareBytes = null;
      _fileName = null;
    });
  }

  void _selectBoard(String name) {
    CatalogBoard? board;
    for (final b in _activeSource?.boards ?? const <CatalogBoard>[]) {
      if (b.name == name) board = b;
    }
    final romType = board?.romTypes.firstOrNull;
    _selectedVariantByTag.clear();
    setState(() {
      _selectedBoard = name;
      _boardListOpen = false;
      _selectedRomType = romType;
      _firmwareBytes = null;
      _fileName = null;
    });
  }

  void _stepBoard(int direction) {
    final boards = (_activeSource?.boards ?? const <CatalogBoard>[])
        .map((b) => b.name)
        .toList();
    if (boards.isEmpty) return;
    final selected = _selectedBoard;
    final index = selected == null ? -1 : boards.indexOf(selected);
    final next = index == -1
        ? boards.first
        : boards[(index + direction + boards.length) % boards.length];
    _selectBoard(next);
  }

  void _selectRomType(CatalogRomType romType) {
    _selectedVariantByTag.clear();
    setState(() {
      _selectedRomType = romType;
      _firmwareBytes = null;
      _fileName = null;
    });
  }

  Future<void> _pickFile() async {
    // file_picker 12.x: FilePicker.pickFile() is a static method (no more
    // .platform singleton getter) and returns a single PlatformFile?
    // directly (no FilePickerResult wrapper). Bytes are no longer carried
    // on the PlatformFile itself (the withData param is deprecated and
    // doesn't populate anything useful here) — read them explicitly instead.
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['bin'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _firmwareBytes = bytes;
      _fileName = file.name;
    });
  }

  Future<void> _useCustomUrl() async {
    final url = _customUrlController.text.trim();
    if (url.isEmpty) return;
    final asset = _catalogService.fromCustomUrl(
      url,
      flashOffset: _selectedOffset,
    );
    final bytes = await asset.fetch();
    setState(() {
      _firmwareBytes = bytes;
      _fileName = url;
    });
  }

  FlasherActionState _stateFor(CatalogFile file) =>
      _fileStates[file.url] ??
      (_downloadedBytes.containsKey(file.url)
          ? const FlasherActionState(phase: FlasherRowPhase.ready)
          : const FlasherActionState());

  void _onTapAction(CatalogFile file) {
    final state = _stateFor(file);
    if (state.isBusy) return;
    if (state.phase == FlasherRowPhase.ready) {
      unawaited(_flashFile(file));
    } else {
      unawaited(_downloadFile(file));
    }
  }

  Future<void> _downloadFile(CatalogFile file) async {
    setState(
      () => _fileStates[file.url] = const FlasherActionState(
        phase: FlasherRowPhase.downloading,
      ),
    );
    try {
      final bytes = await _catalogService
          .assetFor(file)
          .fetch(
            onProgress: (p) {
              if (!mounted) return;
              setState(
                () => _fileStates[file.url] = FlasherActionState(
                  phase: FlasherRowPhase.downloading,
                  progress: p,
                ),
              );
            },
          );
      if (!mounted) return;
      _downloadedBytes[file.url] = bytes;
      final label = file.offset == catalogOffsetFullReset
          ? context.l10n.flasherFullResetShortLabel
          : context.l10n.flasherUpdateShortLabel;
      setState(
        () => _fileStates[file.url] = FlasherActionState(
          // phase must stay `ready` (not the default `idle`) — otherwise a
          // tap during this completion-message window falls through
          // _stateFor's idle branch and re-triggers a download instead of
          // flashing the already-downloaded bytes.
          phase: FlasherRowPhase.ready,
          completionMessage: context.l10n.flasherDownloadedFile(label),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(
        () => _fileStates[file.url] = const FlasherActionState(
          phase: FlasherRowPhase.ready,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _fileStates.remove(file.url));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.flasherError(e.toString()))),
      );
    }
  }

  /// Shared by both flashing entry points (this row-based flow and the
  /// existing Local file/Custom URL `_confirmAndStartFlashing`) — extracted
  /// here instead of duplicated so there is exactly one place that builds
  /// this dialog.
  Future<bool> _confirmFullReset() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.flasherFullResetConfirmTitle),
        content: Text(l10n.flasherFullResetConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.flasherFullResetConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.flasherFullResetConfirmProceed),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _flashFile(CatalogFile file) async {
    // Defensive backstop: the row-builder already disables every icon while
    // a flash is in progress (gated on _step), but this guard makes it
    // impossible for a second concurrent flash to actually start even if
    // that UI-level gating is ever bypassed — two flashes racing over the
    // same physical serial port is a real hardware-safety risk, not
    // cosmetic.
    if (_step != FlasherStep.pickFile) return;
    if (file.offset == catalogOffsetFullReset && !await _confirmFullReset()) {
      return;
    }
    if (!mounted) return;
    final bytes = _downloadedBytes[file.url];
    if (bytes == null) return;
    setState(
      () => _fileStates[file.url] = const FlasherActionState(
        phase: FlasherRowPhase.flashing,
      ),
    );
    final succeeded = await _startFlashing(
      firmware: bytes,
      offset: file.offset,
      onProgress: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          _fileStates[file.url] = FlasherActionState(
            phase: FlasherRowPhase.flashing,
            progress: p,
          );
        });
      },
    );
    if (!mounted) return;
    if (!succeeded) {
      // The top-level error banner already told the user what happened —
      // don't also claim success on this row with a false "✓ Flashed".
      setState(
        () => _fileStates[file.url] = const FlasherActionState(
          phase: FlasherRowPhase.ready,
        ),
      );
      return;
    }
    final label = file.offset == catalogOffsetFullReset
        ? context.l10n.flasherFullResetShortLabel
        : context.l10n.flasherUpdateShortLabel;
    setState(
      () => _fileStates[file.url] = FlasherActionState(
        completionMessage: context.l10n.flasherFlashedFile(label),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(
      () => _fileStates[file.url] = const FlasherActionState(
        phase: FlasherRowPhase.ready,
      ),
    );
  }

  Future<void> _confirmAndStartFlashing() async {
    if (_selectedOffset == catalogOffsetFullReset &&
        !await _confirmFullReset()) {
      return;
    }
    if (!mounted) return;
    await _startFlashing(
      firmware: _firmwareBytes!,
      offset: _selectedOffset,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _progress = p);
      },
    );
  }

  void _dismissSuccessBanner() {
    _successBannerTimer?.cancel();
    setState(() => _step = FlasherStep.pickFile);
  }

  /// Returns `true` on a successful flash (the existing `FlasherStep.done` +
  /// banner-timer path), `false` on failure (the existing `catch` path) —
  /// callers use this to avoid reporting a false success when the flash
  /// actually failed.
  Future<bool> _startFlashing({
    required Uint8List firmware,
    required int offset,
    required void Function(double progress) onProgress,
  }) async {
    setState(() {
      _step = FlasherStep.connect;
      _errorMessage = null;
    });

    final usb = UsbSerialService();
    var connected = false;
    EspFlashProtocol? protocol;
    try {
      final ports = await usb.listPorts();
      if (ports.isEmpty) {
        throw StateError('No USB serial device found');
      }
      await usb.connect(portName: ports.first, baudRate: 115200);
      connected = true;
      final transport = EspSerialTransport(usb);
      await transport.resetIntoBootloader();
      protocol = EspFlashProtocol(transport);
      await protocol.sync();

      setState(() => _step = FlasherStep.flashing);
      await protocol.attachSpiFlash();
      await for (final progress in protocol.flashImage(
        image: firmware,
        offset: offset,
      )) {
        onProgress(progress);
      }
      // Boot the freshly written firmware — FLASH_END parks the chip in
      // the ROM loader, so reset it the same way esptool does.
      await transport.hardReset();

      setState(() => _step = FlasherStep.done);
      _successBannerTimer?.cancel();
      _successBannerTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _step = FlasherStep.pickFile);
      });
      return true;
    } catch (error) {
      setState(() {
        _step = FlasherStep.error;
        _errorMessage = error.toString();
      });
      return false;
    } finally {
      await protocol?.dispose();
      // Added after external review: without this, a failed or completed
      // flash left the USB port open and DTR/RTS in whatever state the
      // sequence last set them to, so a retry (or connecting a MeshCore
      // companion afterward) often required restarting the app. Always
      // release the port, regardless of outcome.
      if (connected) {
        await usb.disconnect();
      }
    }
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
    padding: EdgeInsets.only(
      top: MeshTokens.of(context).spacingSm,
      bottom: MeshTokens.of(context).spacingXs,
    ),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.6,
        color: MeshTokens.of(context).ink3,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(l10n.hubFlasherTile),
        actions: const [_FlasherMenuButton()],
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: MeshTokens.of(context).spacingXs,
                    runSpacing: MeshTokens.of(context).spacingXs,
                    children: [
                      SelectableChipButton(
                        label: l10n.flasherSourceMeshCore,
                        selected: _sourceKind == _FirmwareSourceKind.meshcore,
                        onTap: () {
                          setState(
                            () => _sourceKind = _FirmwareSourceKind.meshcore,
                          );
                          _resetSelection();
                        },
                      ),
                      SelectableChipButton(
                        label: l10n.flasherSourceMeshCoreSolo,
                        selected:
                            _sourceKind == _FirmwareSourceKind.meshcoreSolo,
                        onTap: () {
                          setState(
                            () =>
                                _sourceKind = _FirmwareSourceKind.meshcoreSolo,
                          );
                          _resetSelection();
                        },
                      ),
                      SelectableChipButton(
                        label: l10n.flasherSourceLocalFile,
                        selected: _sourceKind == _FirmwareSourceKind.localFile,
                        onTap: () => setState(
                          () => _sourceKind = _FirmwareSourceKind.localFile,
                        ),
                      ),
                      SelectableChipButton(
                        label: l10n.flasherSourceCustomUrl,
                        selected: _sourceKind == _FirmwareSourceKind.customUrl,
                        onTap: () => setState(
                          () => _sourceKind = _FirmwareSourceKind.customUrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Connect/flashing/error status renders right below the
                  // source chips — NOT after the board/ROM/file picker — so
                  // it stays visible without scrolling regardless of how
                  // long the discovered board or version list is (bug fixed
                  // 2026-08-25: the progress bar used to land at the very
                  // bottom of the scrollable content, effectively invisible
                  // during a long list).
                  if (_step == FlasherStep.connect) ...[
                    Text(l10n.flasherConnecting),
                    const SizedBox(height: 8),
                    Text(
                      l10n.flasherBootHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_step == FlasherStep.flashing) ...[
                    Text(l10n.flasherFlashing),
                    LinearProgressIndicator(value: _progress),
                    const SizedBox(height: 16),
                  ],
                  if (_step == FlasherStep.error) ...[
                    Text(l10n.flasherError(_errorMessage ?? '')),
                    const SizedBox(height: 8),
                    // A failed attempt (typically: SYNC timeout because the
                    // board's BOOT button wasn't held) must be retryable in
                    // place — all selections and the downloaded firmware
                    // stay intact, and every retry re-scans USB from
                    // scratch (_startFlashing lists ports fresh each run).
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _step = FlasherStep.pickFile;
                        _errorMessage = null;
                      }),
                      child: Text(l10n.flasherRetry),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_sourceKind == _FirmwareSourceKind.meshcore ||
                      _sourceKind == _FirmwareSourceKind.meshcoreSolo) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _catalog?.generated != null
                                ? l10n.flasherCatalogUpdated(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatShortDate(_catalog!.generated!),
                                  )
                                : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (_refreshingCatalog)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          MeshCircleIconButton(
                            icon: Icons.refresh,
                            size: 32,
                            iconSize: 16,
                            tooltip: l10n.flasherRefreshTooltip,
                            onPressed: _refreshCatalog,
                          ),
                      ],
                    ),
                    if (_catalogError != null)
                      Text(l10n.flasherError(_catalogError!)),
                    if (_catalog == null && _catalogError == null)
                      const Center(child: CircularProgressIndicator())
                    else if (_catalog != null) ...[
                      _sectionLabel(context, l10n.flasherBoardLabel),
                      if ((_activeSource?.boards ?? const []).isEmpty)
                        Text(l10n.flasherNoBoardsFound)
                      else
                        _BoardPickerField(
                          boards: _activeSource!.boards
                              .map((b) => b.name)
                              .toList(),
                          selected: _selectedBoard,
                          isOpen: _boardListOpen,
                          onToggle: () =>
                              setState(() => _boardListOpen = !_boardListOpen),
                          onStep: _stepBoard,
                          onSelect: _selectBoard,
                          placeholder: l10n.flasherSelectBoard,
                          searchHint: l10n.flasherSearchBoardHint,
                        ),
                      if (_activeBoard != null) ...[
                        if (_activeBoard!.romTypes.length > 1) ...[
                          _sectionLabel(context, l10n.flasherRomTypeLabel),
                          Wrap(
                            spacing: MeshTokens.of(context).spacingXs,
                            runSpacing: MeshTokens.of(context).spacingXs,
                            children: _activeBoard!.romTypes
                                .map(
                                  (romType) => SelectableChipButton(
                                    label: romType.displayName,
                                    selected:
                                        _selectedRomType?.id == romType.id,
                                    onTap: () => _selectRomType(romType),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_selectedRomType != null) ...[
                          _sectionLabel(context, l10n.flasherVersionLabel),
                          ConstrainedBox(
                            key: const Key('flasherVersionListConstrainedBox'),
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(t.sm),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _selectedRomType!.versions.length,
                                separatorBuilder: (_, _) =>
                                    const MeshDashedDivider(
                                      indent: 14,
                                      endIndent: 14,
                                    ),
                                itemBuilder: (context, index) {
                                  final version =
                                      _selectedRomType!.versions[index];
                                  final variants = _variantsFor(version);
                                  final hasVariantChoice = variants.length > 1;
                                  final selectedVariant = hasVariantChoice
                                      ? (_selectedVariantByTag[version.tag] ??
                                            variants.first)
                                      : (variants.firstOrNull ??
                                            _FileVariant.generic);
                                  final variantFiles = version.files
                                      .where(
                                        (f) => _variantOf(f) == selectedVariant,
                                      )
                                      .toList();
                                  final resetFile = variantFiles
                                      .where(
                                        (f) =>
                                            f.offset == catalogOffsetFullReset,
                                      )
                                      .firstOrNull;
                                  final updateFile = variantFiles
                                      .where(
                                        (f) => f.offset == catalogOffsetUpdate,
                                      )
                                      .firstOrNull;
                                  return FlasherVersionRow(
                                    tag: version.tag,
                                    subLabel:
                                        (resetFile ?? updateFile)?.name ??
                                        version.tag,
                                    resetState: resetFile == null
                                        ? const FlasherActionState()
                                        : _stateFor(resetFile),
                                    updateState: updateFile == null
                                        ? const FlasherActionState()
                                        : _stateFor(updateFile),
                                    onTapReset:
                                        (resetFile == null ||
                                            _step != FlasherStep.pickFile)
                                        ? null
                                        : () => _onTapAction(resetFile),
                                    onTapUpdate:
                                        (updateFile == null ||
                                            _step != FlasherStep.pickFile)
                                        ? null
                                        : () => _onTapAction(updateFile),
                                    variantLabels: hasVariantChoice
                                        ? [
                                            for (final v in variants)
                                              _variantLabel(v),
                                          ]
                                        : const [],
                                    selectedVariantIndex: hasVariantChoice
                                        ? variants.indexOf(selectedVariant)
                                        : 0,
                                    onSelectVariant: hasVariantChoice
                                        ? (index) => setState(
                                            () =>
                                                _selectedVariantByTag[version
                                                        .tag] =
                                                    variants[index],
                                          )
                                        : null,
                                  );
                                },
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(top: t.spacingXxs),
                            child: Text(
                              l10n.flasherIconLegend,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: t.ink3),
                            ),
                          ),
                        ],
                      ],
                    ],
                    const SizedBox(height: 16),
                  ],
                  if (_sourceKind == _FirmwareSourceKind.customUrl) ...[
                    TextField(
                      controller: _customUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.flasherSourceCustomUrl,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _useCustomUrl,
                      child: Text(_fileName ?? l10n.flasherSourceCustomUrl),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_sourceKind == _FirmwareSourceKind.localFile) ...[
                    OutlinedButton(
                      onPressed: _step == FlasherStep.pickFile
                          ? _pickFile
                          : null,
                      child: Text(_fileName ?? l10n.flasherPickFile),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          if (_step == FlasherStep.done)
            _SuccessBanner(
              message: l10n.flasherDone,
              onTap: _dismissSuccessBanner,
            ),
        ],
      ),
      // Fixed footer, outside the scrollable content — the Start button can
      // never be scrolled out of reach or clipped by the system gesture-nav
      // bar (SafeArea here covers exactly that), and it never triggers a
      // RenderFlex overflow the way a Spacer-filled Column inside a
      // SingleChildScrollView's unbounded height would.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _firmwareBytes != null && _step == FlasherStep.pickFile
                ? _confirmAndStartFlashing
                : null,
            child: Text(l10n.flasherStart),
          ),
        ),
      ),
    );
  }
}

class _BoardPickerField extends StatefulWidget {
  const _BoardPickerField({
    required this.boards,
    required this.selected,
    required this.isOpen,
    required this.onToggle,
    required this.onStep,
    required this.onSelect,
    required this.placeholder,
    required this.searchHint,
  });

  final List<String> boards;
  final String? selected;
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<int> onStep;
  final ValueChanged<String> onSelect;
  final String placeholder;
  final String searchHint;

  @override
  State<_BoardPickerField> createState() => _BoardPickerFieldState();
}

class _BoardPickerFieldState extends State<_BoardPickerField> {
  final TextEditingController _filterController = TextEditingController();

  List<String> get boards => widget.boards;
  String? get selected => widget.selected;
  bool get isOpen => widget.isOpen;
  VoidCallback get onToggle => widget.onToggle;
  ValueChanged<int> get onStep => widget.onStep;
  ValueChanged<String> get onSelect => widget.onSelect;
  String get placeholder => widget.placeholder;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _BoardPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Stale filter text from a previous open would silently hide boards
    // the next time the list expands — reset it whenever the list closes.
    if (oldWidget.isOpen && !widget.isOpen) {
      _filterController.clear();
    }
  }

  List<String> get _filteredBoards {
    final query = _filterController.text.trim().toLowerCase();
    if (query.isEmpty) return boards;
    return boards.where((b) => b.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            MeshCircleIconButton(
              icon: Icons.remove,
              onPressed: boards.isEmpty ? null : () => onStep(-1),
            ),
            SizedBox(width: t.spacingXxs),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(t.sm),
                onTap: boards.isEmpty ? null : onToggle,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.spacingSm,
                    vertical: t.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(t.sm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selected ?? placeholder,
                        style: t.monoBody(color: scheme.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Icon(
                        isOpen ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: t.spacingXxs),
            MeshCircleIconButton(
              icon: Icons.add,
              onPressed: boards.isEmpty ? null : () => onStep(1),
            ),
          ],
        ),
        if (isOpen)
          Container(
            margin: EdgeInsets.only(top: t.spacingXs),
            constraints: const BoxConstraints(maxHeight: 280),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.sm),
            ),
            // ListTile paints its background/ink splashes on the nearest
            // Material ancestor — a plain Container/BoxDecoration here (as
            // opposed to Material) leaves them invisible and trips a
            // debug-mode framework assertion, so the surface color lives on
            // this Material instead of a DecoratedBox.
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Type-to-filter, meshcore.io/flasher-style: the full
                  // discovered board list can be long, so the expanded
                  // panel leads with a search field narrowing it live.
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spacingSm,
                      vertical: t.spacingXxs,
                    ),
                    child: TextField(
                      controller: _filterController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        hintText: widget.searchHint,
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _filteredBoards.length,
                      separatorBuilder: (_, _) =>
                          const MeshDashedDivider(indent: 14, endIndent: 14),
                      itemBuilder: (context, index) {
                        final board = _filteredBoards[index];
                        final isSelected = board == selected;
                        return ListTile(
                          dense: true,
                          title: Text(board),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: scheme.primary,
                                )
                              : null,
                          onTap: () => onSelect(board),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _FlasherMenuButton extends StatelessWidget {
  const _FlasherMenuButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: context.l10n.contacts_moreOptions,
      itemBuilder: (context) => [
        PopupMenuItem(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FlasherAboutScreen()),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline),
              SizedBox(width: MeshTokens.of(context).spacingXs),
              Text(context.l10n.flasherAboutMenuItem),
            ],
          ),
        ),
        const PopupMenuDivider(),
        ...quickAccessMenuItems(context),
      ],
      // Deliberate, user-confirmed exception to the flat AppBarMenuIcon
      // pattern used elsewhere in the app.
      child: const MeshCircleIconButton(
        icon: Icons.more_vert,
        onPressed: null,
        decorative: true,
        size: 32,
        iconSize: 16,
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message, required this.onTap});

  final String message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = MeshTokens.of(context);
    final signal = t.signal;
    return Positioned(
      top: 12,
      left: 10,
      right: 10,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * -24),
              child: child,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(t.md),
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: t.spacingMd,
                  vertical: t.spacingSm,
                ),
                decoration: BoxDecoration(
                  color: signal.withValues(alpha: 0.16),
                  border: Border.all(color: signal),
                  borderRadius: BorderRadius.circular(t.md),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: signal.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 16, color: signal),
                    ),
                    SizedBox(width: t.spacingSm),
                    Expanded(
                      child: Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
