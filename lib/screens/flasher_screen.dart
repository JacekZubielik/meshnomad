import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/esp_flash/esp_flash_protocol.dart';
import '../services/esp_flash/esp_serial_transport.dart';
import '../services/firmware_source.dart';
import '../services/usb_serial_service.dart';
import '../theme/mesh_tokens.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/theme_profile_selector.dart' show SelectableChipButton;

enum FlasherStep { pickFile, connect, flashing, done, error }

enum _FirmwareSourceKind { meshcore, meshcoreSolo, localFile, customUrl }

/// Flasher wizard: offers four firmware sources (MeshCore, MeshCore-Solo,
/// local file, custom URL) via [FirmwareSource] (task 08), with the flash
/// offset selected per-asset instead of hardcoded (task 09).
class FlasherScreen extends StatefulWidget {
  const FlasherScreen({super.key, FirmwareSource? firmwareSource})
    : _firmwareSource = firmwareSource;

  final FirmwareSource? _firmwareSource;

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
  int _selectedOffset = flashOffsetUpdate;
  late final FirmwareSource _firmwareSource;
  List<FirmwareGithubSource>? _catalog;
  List<String>? _boards;
  String? _boardsError;
  String? _selectedBoard;
  bool _boardListOpen = false;
  FirmwareRomType? _selectedRomType;
  List<FirmwareRelease>? _releases;
  String? _releasesError;
  FirmwareRelease? _selectedRelease;
  final TextEditingController _customUrlController = TextEditingController();
  Timer? _successBannerTimer;

  @override
  void initState() {
    super.initState();
    _firmwareSource = widget._firmwareSource ?? FirmwareSource();
    // MeshCore is the default-selected chip (see `_sourceKind`'s initializer)
    // — without this, the catalog never loads until the user taps a chip,
    // leaving the board picker's CircularProgressIndicator spinning forever
    // on first open.
    _loadCatalogIfNeeded();
  }

  @override
  void dispose() {
    _successBannerTimer?.cancel();
    _customUrlController.dispose();
    super.dispose();
  }

  /// The catalog entry for whichever built-in GitHub source is currently
  /// selected — null while `_sourceKind` is localFile/customUrl, or before
  /// `_catalog` has loaded.
  FirmwareGithubSource? get _activeSource {
    final catalog = _catalog;
    if (catalog == null) return null;
    final id = switch (_sourceKind) {
      _FirmwareSourceKind.meshcore => 'meshcore',
      _FirmwareSourceKind.meshcoreSolo => 'meshcore_solo',
      _ => null,
    };
    if (id == null) return null;
    return catalog.firstWhere((s) => s.id == id);
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

  Future<void> _loadCatalogIfNeeded() async {
    if (_catalog != null) return;
    final catalog = await _firmwareSource.loadCatalog();
    if (!mounted) return;
    setState(() => _catalog = catalog);
    await _loadBoards();
  }

  /// Board choice comes first (per operator decision — the board picker
  /// must not depend on a ROM type or version being chosen yet), so this
  /// discovers the live board list before anything else loads. Called on
  /// initial catalog load and every time the active source chip changes.
  Future<void> _loadBoards() async {
    final source = _activeSource;
    if (source == null) return;
    setState(() {
      _boards = null;
      _boardsError = null;
      _selectedBoard = null;
      _boardListOpen = false;
    });
    List<String> boards;
    String? error;
    try {
      boards = await _firmwareSource.discoverBoards(source: source);
    } catch (e) {
      boards = const [];
      error = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _boards = boards;
      _boardsError = error;
      _selectedBoard = boards.firstOrNull;
      // Default to the first ROM type of whichever source is active (if it
      // has any — MeshCore-Solo has none) so releases load immediately
      // instead of waiting for a chip tap.
      _selectedRomType = source.romTypes.firstOrNull;
    });
    await _loadReleases();
  }

  Future<void> _selectBoard(String board) async {
    setState(() {
      _selectedBoard = board;
      _boardListOpen = false;
    });
    await _loadReleases();
  }

  /// Cycles to the previous/next board in the active source's discovered
  /// list — the `SettingsValueStepper`-style +/- circles next to the
  /// tap-to-expand pill.
  void _stepBoard(int direction) {
    final boards = _boards;
    if (boards == null || boards.isEmpty) return;
    final selected = _selectedBoard;
    final index = selected == null ? -1 : boards.indexOf(selected);
    final next = index == -1
        ? boards.first
        : boards[(index + direction + boards.length) % boards.length];
    _selectBoard(next);
  }

  Future<void> _loadReleases() async {
    final source = _activeSource;
    final board = _selectedBoard;
    if (source == null || board == null) {
      setState(() {
        _releases = null;
        _releasesError = null;
        _selectedRelease = null;
      });
      return;
    }
    setState(() {
      _releases = null;
      _releasesError = null;
      _selectedRelease = null;
    });
    List<FirmwareRelease> releases;
    String? error;
    try {
      releases = await _firmwareSource.fetchReleases(
        source: source,
        romType: _selectedRomType,
        boardToken: board,
      );
    } catch (e) {
      // A failed release fetch (offline, rate-limited, GitHub down) should
      // leave the picker on an empty release list rather than crash the
      // screen — the user can still fall back to Local file/Custom URL —
      // but the failure reason must stay visible; silently mapping every
      // exception to a bare "no releases found" hid real API errors (a
      // real-world 403 rate-limit response looked identical to an
      // honestly-empty catalog, which cost real debugging time).
      releases = const [];
      error = e.toString();
    }
    if (!mounted) return;
    setState(() {
      _releases = releases;
      _releasesError = error;
      _selectedRelease = releases.firstOrNull;
      _firmwareBytes = null;
      _fileName = null;
    });
  }

  Future<void> _selectRomType(FirmwareRomType romType) async {
    setState(() => _selectedRomType = romType);
    await _loadReleases();
  }

  Future<void> _selectRelease(FirmwareRelease release) async {
    setState(() {
      _selectedRelease = release;
      _firmwareBytes = null;
      _fileName = null;
    });
  }

  Future<void> _selectGithubAsset(FirmwareAsset asset) async {
    final bytes = await asset.fetch();
    setState(() {
      _firmwareBytes = bytes;
      _fileName = asset.label;
      _selectedOffset = asset.flashOffset;
    });
  }

  Future<void> _useCustomUrl() async {
    final url = _customUrlController.text.trim();
    if (url.isEmpty) return;
    final asset = _firmwareSource.fromCustomUrl(
      url,
      flashOffset: _selectedOffset,
    );
    final bytes = await asset.fetch();
    setState(() {
      _firmwareBytes = bytes;
      _fileName = url;
    });
  }

  Future<void> _confirmAndStartFlashing() async {
    if (_selectedOffset == flashOffsetFullReset) {
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
      if (confirmed != true) return;
    }
    if (!mounted) return;
    await _startFlashing();
  }

  void _dismissSuccessBanner() {
    _successBannerTimer?.cancel();
    setState(() => _step = FlasherStep.pickFile);
  }

  Future<void> _startFlashing() async {
    final firmware = _firmwareBytes;
    if (firmware == null) return;
    setState(() {
      _step = FlasherStep.connect;
      _errorMessage = null;
    });

    final usb = UsbSerialService();
    var connected = false;
    try {
      final ports = await usb.listPorts();
      if (ports.isEmpty) {
        throw StateError('No USB serial device found');
      }
      await usb.connect(portName: ports.first, baudRate: 115200);
      connected = true;
      final transport = EspSerialTransport(usb);
      await transport.resetIntoBootloader();
      final protocol = EspFlashProtocol(transport);
      await protocol.sync();

      setState(() => _step = FlasherStep.flashing);
      await protocol.attachSpiFlash();
      await for (final progress in protocol.flashImage(
        image: firmware,
        offset: _selectedOffset,
      )) {
        setState(() => _progress = progress);
      }

      setState(() => _step = FlasherStep.done);
      _successBannerTimer?.cancel();
      _successBannerTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() => _step = FlasherStep.pickFile);
      });
    } catch (error) {
      setState(() {
        _step = FlasherStep.error;
        _errorMessage = error.toString();
      });
    } finally {
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
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text(l10n.hubFlasherTile)),
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
                          _loadBoards();
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
                          _loadBoards();
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
                  if (_sourceKind == _FirmwareSourceKind.meshcore ||
                      _sourceKind == _FirmwareSourceKind.meshcoreSolo) ...[
                    if (_catalog == null)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _sectionLabel(context, l10n.flasherBoardLabel),
                      if (_boards == null)
                        const Center(child: CircularProgressIndicator())
                      else if (_boards!.isEmpty)
                        Text(
                          _boardsError != null
                              ? l10n.flasherError(_boardsError!)
                              : l10n.flasherNoBoardsFound,
                        )
                      else
                        _BoardPickerField(
                          boards: _boards!,
                          selected: _selectedBoard,
                          isOpen: _boardListOpen,
                          onToggle: () =>
                              setState(() => _boardListOpen = !_boardListOpen),
                          onStep: _stepBoard,
                          onSelect: _selectBoard,
                          placeholder: l10n.flasherSelectBoard,
                          searchHint: l10n.flasherSearchBoardHint,
                        ),
                      if (_selectedBoard != null) ...[
                        if ((_activeSource?.romTypes ?? const [])
                            .isNotEmpty) ...[
                          _sectionLabel(context, l10n.flasherRomTypeLabel),
                          Wrap(
                            spacing: MeshTokens.of(context).spacingXs,
                            runSpacing: MeshTokens.of(context).spacingXs,
                            children: _activeSource!.romTypes
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
                          // The dropdown's floating label renders above the
                          // field's own bounds — without this gap it lands
                          // on top of the ROM-type chips.
                          const SizedBox(height: 16),
                        ],
                        if (_releases == null)
                          const Center(child: CircularProgressIndicator())
                        else if (_releases!.isEmpty)
                          Text(
                            _releasesError != null
                                ? l10n.flasherError(_releasesError!)
                                : l10n.flasherNoReleasesFound,
                          )
                        else ...[
                          DropdownButtonFormField<FirmwareRelease>(
                            initialValue: _selectedRelease,
                            decoration: InputDecoration(
                              labelText: l10n.flasherSelectVersion,
                            ),
                            items: _releases!
                                .map(
                                  (release) => DropdownMenuItem(
                                    value: release,
                                    child: Text(release.tagName),
                                  ),
                                )
                                .toList(),
                            onChanged: (release) {
                              if (release != null) _selectRelease(release);
                            },
                          ),
                          _sectionLabel(context, l10n.flasherFileLabel),
                          // Radio identity is the asset's unique filename —
                          // NOT its flash offset: a release routinely ships
                          // several assets sharing one offset (BLE + USB
                          // role variants are both plain-update images), and
                          // keying the group on offset rendered them all as
                          // simultaneously selected.
                          ...(_selectedRelease?.assets ?? const []).map(
                            (asset) => RadioListTile<String>(
                              title: Text(
                                asset.flashOffset == flashOffsetFullReset
                                    ? l10n.flasherFullResetOption
                                    : l10n.flasherUpdateOption,
                              ),
                              subtitle: Text(asset.label),
                              value: asset.label,
                              groupValue: _fileName,
                              onChanged: (_) => _selectGithubAsset(asset),
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
                  if (_step == FlasherStep.connect) ...[
                    Text(l10n.flasherConnecting),
                    const SizedBox(height: 8),
                    Text(
                      l10n.flasherBootHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_step == FlasherStep.flashing) ...[
                    Text(l10n.flasherFlashing),
                    LinearProgressIndicator(value: _progress),
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

  Widget _circleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 36,
      height: 36,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: scheme.primary.withValues(alpha: 0.2),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 18,
          color: scheme.primary,
          icon: Icon(icon),
          onPressed: boards.isEmpty ? null : onPressed,
        ),
      ),
    );
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
            _circleButton(
              context,
              icon: Icons.remove,
              onPressed: () => onStep(-1),
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
            _circleButton(context, icon: Icons.add, onPressed: () => onStep(1)),
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
