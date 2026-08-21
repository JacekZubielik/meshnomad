import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import 'dotted_separator.dart';
import 'repeater_command_param_popup.dart';

class _CommandHelpEntry {
  final String command;
  final String description;
  final bool serialOnly;
  const _CommandHelpEntry({
    required this.command,
    required this.description,
    this.serialOnly = false,
  });
}

class _CommandGroup {
  final String label;
  final List<_CommandHelpEntry> entries;
  const _CommandGroup({required this.label, required this.entries});
}

class RepeaterCommandDrawer {
  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onCommandSelected,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _RepeaterCommandDrawerBody(onCommandSelected: onCommandSelected),
    );
  }
}

class _RepeaterCommandDrawerBody extends StatefulWidget {
  final ValueChanged<String> onCommandSelected;

  const _RepeaterCommandDrawerBody({required this.onCommandSelected});

  @override
  State<_RepeaterCommandDrawerBody> createState() =>
      _RepeaterCommandDrawerBodyState();
}

class _RepeaterCommandDrawerBodyState
    extends State<_RepeaterCommandDrawerBody> {
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final Map<String, GlobalKey> _groupKeys = {};
  ScrollController? _activeScrollController;

  // Three-stop size cycle for the size-toggle header action: default (60%)
  // -> max (88%) -> full (100%) -> back to default. Matches the
  // DraggableScrollableSheet's own snapSizes below, so a manual drag settles
  // on the same three stops the button cycles through.
  static const List<double> _sheetStops = [0.6, 0.88, 1.0];
  int _sizeState = 0;

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_handleSheetExtentChanged);
  }

  void _handleSheetExtentChanged() {
    if (!_sheetController.isAttached) return;
    final size = _sheetController.size;
    var nearest = 0;
    var nearestDist = (size - _sheetStops[0]).abs();
    for (var i = 1; i < _sheetStops.length; i++) {
      final dist = (size - _sheetStops[i]).abs();
      if (dist < nearestDist) {
        nearest = i;
        nearestDist = dist;
      }
    }
    if (nearest != _sizeState) {
      setState(() => _sizeState = nearest);
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_handleSheetExtentChanged);
    _sheetController.dispose();
    super.dispose();
  }

  List<_CommandGroup> _buildGroups(AppLocalizations l10n) {
    return [
      _CommandGroup(
        label: 'Info',
        entries: [
          _CommandHelpEntry(
            command: 'ver',
            description: l10n.repeater_cliHelpVersion,
          ),
          _CommandHelpEntry(
            command: 'board',
            description: l10n.repeater_cliHelpBoard,
          ),
          _CommandHelpEntry(
            command: 'clock',
            description: l10n.repeater_cliHelpClock,
          ),
          _CommandHelpEntry(
            command: 'time {epoch-seconds}',
            description: l10n.repeater_cliHelpTime,
          ),
          _CommandHelpEntry(
            command: 'get public.key',
            description: l10n.repeater_cliHelpGetPublicKey,
          ),
          _CommandHelpEntry(
            command: 'get role',
            description: l10n.repeater_cliHelpGetRole,
          ),
          _CommandHelpEntry(
            command: 'get owner.info',
            description: l10n.repeater_cliHelpGetOwnerInfo,
          ),
          _CommandHelpEntry(
            command: 'set owner.info {text}',
            description: l10n.repeater_cliHelpSetOwnerInfo,
          ),
          _CommandHelpEntry(
            command: 'get name',
            description: l10n.repeater_cliHelpGetName,
          ),
          _CommandHelpEntry(
            command: 'get bootloader.ver',
            description: l10n.repeater_cliHelpGetBootloaderVer,
          ),
          _CommandHelpEntry(
            command: 'stats-core',
            description: l10n.repeater_cliHelpStatsCore,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'stats-radio',
            description: l10n.repeater_cliHelpStatsRadio,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'stats-packets',
            description: l10n.repeater_cliHelpStatsPackets,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'clear stats',
            description: l10n.repeater_cliHelpClearStats,
          ),
          _CommandHelpEntry(
            command: 'sensor list [start]',
            description: l10n.repeater_cliHelpSensorList,
          ),
          _CommandHelpEntry(
            command: 'sensor get {key}',
            description: l10n.repeater_cliHelpSensorGet,
          ),
          _CommandHelpEntry(
            command: 'sensor set {key} {value}',
            description: l10n.repeater_cliHelpSensorSet,
          ),
          _CommandHelpEntry(
            command: 'get pwrmgt.support',
            description: l10n.repeater_cliHelpGetPwrMgtSupport,
          ),
          _CommandHelpEntry(
            command: 'get pwrmgt.source',
            description: l10n.repeater_cliHelpGetPwrMgtSource,
          ),
          _CommandHelpEntry(
            command: 'get pwrmgt.bootreason',
            description: l10n.repeater_cliHelpGetPwrMgtBootReason,
          ),
          _CommandHelpEntry(
            command: 'get pwrmgt.bootmv',
            description: l10n.repeater_cliHelpGetPwrMgtBootMv,
          ),
        ],
      ),
      _CommandGroup(
        label: 'Radio',
        entries: [
          _CommandHelpEntry(
            command: 'get radio',
            description: l10n.repeater_cliHelpGetRadio,
          ),
          _CommandHelpEntry(
            command: 'set radio {freq},{bw},{sf},{cr}',
            description: l10n.repeater_cliHelpSetRadio,
          ),
          _CommandHelpEntry(
            command: 'get tx',
            description: l10n.repeater_cliHelpGetTx,
          ),
          _CommandHelpEntry(
            command: 'set tx {tx-power-dbm}',
            description: l10n.repeater_cliHelpSetTx,
          ),
          _CommandHelpEntry(
            command: 'get freq',
            description: l10n.repeater_cliHelpGetFreq,
          ),
          _CommandHelpEntry(
            command: 'set freq {mhz}',
            description: l10n.repeater_cliHelpSetFreq,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'get radio.rxgain',
            description: l10n.repeater_cliHelpGetRadioRxGain,
          ),
          _CommandHelpEntry(
            command: 'set radio.rxgain {on|off}',
            description: l10n.repeater_cliHelpSetRadioRxGain,
          ),
          _CommandHelpEntry(
            command: 'set radio.fem.rxgain',
            description: l10n.repeater_cliHelpSetRadioFemRxgain,
          ),
          _CommandHelpEntry(
            command: 'set radio.fem.txgain',
            description: l10n.repeater_cliHelpSetRadioFemTxgain,
          ),
          _CommandHelpEntry(
            command: 'set cad',
            description: l10n.repeater_cliHelpSetCad,
          ),
          _CommandHelpEntry(
            command: 'set extra.sf',
            description: l10n.repeater_cliHelpSetExtraSf,
          ),
          _CommandHelpEntry(
            command: 'tempradio {freq},{bw},{sf},{cr},{minutes}',
            description: l10n.repeater_cliHelpTempRadio,
          ),
          _CommandHelpEntry(
            command: 'get agc.reset.interval',
            description: l10n.repeater_cliHelpGetAgcResetInterval,
          ),
          _CommandHelpEntry(
            command: 'set agc.reset.interval {seconds}',
            description: l10n.repeater_cliHelpSetAgcResetInterval,
          ),
          _CommandHelpEntry(
            command: 'get int.thresh',
            description: l10n.repeater_cliHelpGetIntThresh,
          ),
          _CommandHelpEntry(
            command: 'set int.thresh {db}',
            description: l10n.repeater_cliHelpSetIntThresh,
          ),
          _CommandHelpEntry(
            command: 'get adc.multiplier',
            description: l10n.repeater_cliHelpGetAdcMultiplier,
          ),
          _CommandHelpEntry(
            command: 'set adc.multiplier {factor}',
            description: l10n.repeater_cliHelpSetAdcMultiplier,
          ),
          _CommandHelpEntry(
            command: 'region',
            description: l10n.repeater_cliHelpRegion,
          ),
          _CommandHelpEntry(
            command: 'region load',
            description: l10n.repeater_cliHelpRegionLoad,
          ),
          _CommandHelpEntry(
            command: 'region get {* | name-prefix}',
            description: l10n.repeater_cliHelpRegionGet,
          ),
          _CommandHelpEntry(
            command: 'region put {name} {* | parent-name-prefix}',
            description: l10n.repeater_cliHelpRegionPut,
          ),
          _CommandHelpEntry(
            command: 'region remove {name}',
            description: l10n.repeater_cliHelpRegionRemove,
          ),
          _CommandHelpEntry(
            command: 'region allowf {* | name-prefix}',
            description: l10n.repeater_cliHelpRegionAllowf,
          ),
          _CommandHelpEntry(
            command: 'region denyf {* | name-prefix}',
            description: l10n.repeater_cliHelpRegionDenyf,
          ),
          _CommandHelpEntry(
            command: 'region home',
            description: l10n.repeater_cliHelpRegionHome,
          ),
          _CommandHelpEntry(
            command: 'region home {* | name-prefix}',
            description: l10n.repeater_cliHelpRegionHomeSet,
          ),
          _CommandHelpEntry(
            command: 'region save',
            description: l10n.repeater_cliHelpRegionSave,
          ),
          _CommandHelpEntry(
            command: 'region default',
            description: l10n.repeater_cliHelpRegionDefault,
          ),
          _CommandHelpEntry(
            command: 'region default {* | name-prefix | <null>}',
            description: l10n.repeater_cliHelpRegionDefaultSet,
          ),
          _CommandHelpEntry(
            command: 'region list allowed',
            description: l10n.repeater_cliHelpRegionListAllowed,
          ),
          _CommandHelpEntry(
            command: 'region list denied',
            description: l10n.repeater_cliHelpRegionListDenied,
          ),
        ],
      ),
      _CommandGroup(
        label: 'Flood',
        entries: [
          _CommandHelpEntry(
            command: 'get af',
            description: l10n.repeater_cliHelpGetAf,
          ),
          _CommandHelpEntry(
            command: 'set af {air-time-factor}',
            description: l10n.repeater_cliHelpSetAf,
          ),
          _CommandHelpEntry(
            command: 'get dutycycle',
            description: l10n.repeater_cliHelpGetDutyCycle,
          ),
          _CommandHelpEntry(
            command: 'set dutycycle {1-100}',
            description: l10n.repeater_cliHelpSetDutyCycle,
          ),
          _CommandHelpEntry(
            command: 'get rxdelay',
            description: l10n.repeater_cliHelpGetRxDelay,
          ),
          _CommandHelpEntry(
            command: 'set rxdelay {base}',
            description: l10n.repeater_cliHelpSetRxDelay,
          ),
          _CommandHelpEntry(
            command: 'get txdelay',
            description: l10n.repeater_cliHelpGetTxDelay,
          ),
          _CommandHelpEntry(
            command: 'set txdelay {factor}',
            description: l10n.repeater_cliHelpSetTxDelay,
          ),
          _CommandHelpEntry(
            command: 'get direct.txdelay',
            description: l10n.repeater_cliHelpGetDirectTxDelay,
          ),
          _CommandHelpEntry(
            command: 'set direct.txdelay {factor}',
            description: l10n.repeater_cliHelpSetDirectTxDelay,
          ),
          _CommandHelpEntry(
            command: 'get flood.max',
            description: l10n.repeater_cliHelpGetFloodMax,
          ),
          _CommandHelpEntry(
            command: 'set flood.max {max-hops}',
            description: l10n.repeater_cliHelpSetFloodMax,
          ),
          _CommandHelpEntry(
            command: 'set flood.max.advert',
            description: l10n.repeater_cliHelpSetFloodMaxAdvert,
          ),
          _CommandHelpEntry(
            command: 'set flood.max.unscoped',
            description: l10n.repeater_cliHelpSetFloodMaxUnscoped,
          ),
          _CommandHelpEntry(
            command: 'get flood.advert.interval',
            description: l10n.repeater_cliHelpGetFloodAdvertInterval,
          ),
          _CommandHelpEntry(
            command: 'set flood.advert.interval {hours}',
            description: l10n.repeater_cliHelpSetFloodAdvertInterval,
          ),
          _CommandHelpEntry(
            command: 'get advert.interval',
            description: l10n.repeater_cliHelpGetAdvertInterval,
          ),
          _CommandHelpEntry(
            command: 'set advert.interval {minutes}',
            description: l10n.repeater_cliHelpSetAdvertInterval,
          ),
          _CommandHelpEntry(
            command: 'get path.hash.mode',
            description: l10n.repeater_cliHelpGetPathHashMode,
          ),
          _CommandHelpEntry(
            command: 'set path.hash.mode {0|1|2}',
            description: l10n.repeater_cliHelpSetPathHashMode,
          ),
          _CommandHelpEntry(
            command: 'get loop.detect',
            description: l10n.repeater_cliHelpGetLoopDetect,
          ),
          _CommandHelpEntry(
            command: 'set loop.detect {off|minimal|moderate|strict}',
            description: l10n.repeater_cliHelpSetLoopDetect,
          ),
          _CommandHelpEntry(
            command: 'get multi.acks',
            description: l10n.repeater_cliHelpGetMultiAcks,
          ),
          _CommandHelpEntry(
            command: 'set multi.acks {0|1}',
            description: l10n.repeater_cliHelpSetMultiAcks,
          ),
          _CommandHelpEntry(
            command: 'get repeat',
            description: l10n.repeater_cliHelpGetRepeat,
          ),
          _CommandHelpEntry(
            command: 'set repeat {on|off}',
            description: l10n.repeater_cliHelpSetRepeat,
          ),
          _CommandHelpEntry(
            command: 'neighbors',
            description: l10n.repeater_cliHelpNeighbors,
          ),
          _CommandHelpEntry(
            command: 'neighbor.remove {pubkey-prefix}',
            description: l10n.repeater_cliHelpNeighborRemove,
          ),
          _CommandHelpEntry(
            command: 'discover.neighbors',
            description: l10n.repeater_cliHelpDiscoverNeighbors,
          ),
        ],
      ),
      _CommandGroup(
        label: 'Advert',
        entries: [
          _CommandHelpEntry(
            command: 'advert',
            description: l10n.repeater_cliHelpAdvert,
          ),
          _CommandHelpEntry(
            command: 'advert.zerohop',
            description: l10n.repeater_cliHelpAdvertZeroHop,
          ),
          _CommandHelpEntry(
            command: 'set name {name}',
            description: l10n.repeater_cliHelpSetName,
          ),
          _CommandHelpEntry(
            command: 'set lat {latitude}',
            description: l10n.repeater_cliHelpSetLat,
          ),
          _CommandHelpEntry(
            command: 'get lat',
            description: l10n.repeater_cliHelpGetLat,
          ),
          _CommandHelpEntry(
            command: 'set lon {longitude}',
            description: l10n.repeater_cliHelpSetLon,
          ),
          _CommandHelpEntry(
            command: 'get lon',
            description: l10n.repeater_cliHelpGetLon,
          ),
          _CommandHelpEntry(
            command: 'gps',
            description: l10n.repeater_cliHelpGps,
          ),
          _CommandHelpEntry(
            command: 'gps {on|off}',
            description: l10n.repeater_cliHelpGpsOnOff,
          ),
          _CommandHelpEntry(
            command: 'gps sync',
            description: l10n.repeater_cliHelpGpsSync,
          ),
          _CommandHelpEntry(
            command: 'gps setloc',
            description: l10n.repeater_cliHelpGpsSetLoc,
          ),
          _CommandHelpEntry(
            command: 'gps advert',
            description: l10n.repeater_cliHelpGpsAdvert,
          ),
          _CommandHelpEntry(
            command: 'gps advert {none|share|prefs}',
            description: l10n.repeater_cliHelpGpsAdvertSet,
          ),
        ],
      ),
      _CommandGroup(
        label: 'Bridge',
        entries: [
          _CommandHelpEntry(
            command: 'get bridge.type',
            description: l10n.repeater_cliHelpGetBridgeType,
          ),
          _CommandHelpEntry(
            command: 'get bridge.enabled',
            description: l10n.repeater_cliHelpGetBridgeEnabled,
          ),
          _CommandHelpEntry(
            command: 'set bridge.enabled {on|off}',
            description: l10n.repeater_cliHelpSetBridgeEnabled,
          ),
          _CommandHelpEntry(
            command: 'get bridge.delay',
            description: l10n.repeater_cliHelpGetBridgeDelay,
          ),
          _CommandHelpEntry(
            command: 'set bridge.delay {0-10000}',
            description: l10n.repeater_cliHelpSetBridgeDelay,
          ),
          _CommandHelpEntry(
            command: 'get bridge.source',
            description: l10n.repeater_cliHelpGetBridgeSource,
          ),
          _CommandHelpEntry(
            command: 'set bridge.source {rx|tx}',
            description: l10n.repeater_cliHelpSetBridgeSource,
          ),
          _CommandHelpEntry(
            command: 'get bridge.baud',
            description: l10n.repeater_cliHelpGetBridgeBaud,
          ),
          _CommandHelpEntry(
            command: 'set bridge.baud {speed}',
            description: l10n.repeater_cliHelpSetBridgeBaud,
          ),
          _CommandHelpEntry(
            command: 'get bridge.channel',
            description: l10n.repeater_cliHelpGetBridgeChannel,
          ),
          _CommandHelpEntry(
            command: 'set bridge.channel {1-14}',
            description: l10n.repeater_cliHelpSetBridgeChannel,
          ),
          _CommandHelpEntry(
            command: 'get bridge.secret',
            description: l10n.repeater_cliHelpGetBridgeSecret,
          ),
          _CommandHelpEntry(
            command: 'set bridge.secret {shared-secret}',
            description: l10n.repeater_cliHelpSetBridgeSecret,
          ),
        ],
      ),
      _CommandGroup(
        label: 'Admin',
        entries: [
          _CommandHelpEntry(
            command: 'password {new-password}',
            description: l10n.repeater_cliHelpPassword,
          ),
          _CommandHelpEntry(
            command: 'set guest.password {guess-password}',
            description: l10n.repeater_cliHelpSetGuestPassword,
          ),
          _CommandHelpEntry(
            command: 'get guest.password',
            description: l10n.repeater_cliHelpGetGuestPassword,
          ),
          _CommandHelpEntry(
            command: 'setperm {pubkey-hex} {permissions}',
            description: l10n.repeater_cliHelpSetPerm,
          ),
          _CommandHelpEntry(
            command: 'get acl',
            description: l10n.repeater_cliHelpGetAcl,
          ),
          _CommandHelpEntry(
            command: 'get allow.read.only',
            description: l10n.repeater_cliHelpGetAllowReadOnly,
          ),
          _CommandHelpEntry(
            command: 'set allow.read.only {on|off}',
            description: l10n.repeater_cliHelpSetAllowReadOnly,
          ),
          _CommandHelpEntry(
            command: 'get prv.key',
            description: l10n.repeater_cliHelpGetPrvKey,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'set prv.key {hex}',
            description: l10n.repeater_cliHelpSetPrvKey,
          ),
          _CommandHelpEntry(
            command: 'log start',
            description: l10n.repeater_cliHelpLogStart,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'log stop',
            description: l10n.repeater_cliHelpLogStop,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'log erase',
            description: l10n.repeater_cliHelpLogErase,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'erase',
            description: l10n.repeater_cliHelpErase,
            serialOnly: true,
          ),
          _CommandHelpEntry(
            command: 'start ota',
            description: l10n.repeater_cliHelpStartOta,
          ),
          _CommandHelpEntry(
            command: 'powersaving',
            description: l10n.repeater_cliHelpPowersaving,
          ),
          _CommandHelpEntry(
            command: 'powersaving {on|off}',
            description: l10n.repeater_cliHelpPowersavingOnOff,
          ),
          _CommandHelpEntry(
            command: 'reboot',
            description: l10n.repeater_cliHelpReboot,
          ),
          _CommandHelpEntry(
            command: 'clkreboot',
            description: l10n.repeater_cliHelpClkReboot,
          ),
          _CommandHelpEntry(
            command: 'poweroff',
            description: l10n.repeater_cliHelpPowerOff,
          ),
          _CommandHelpEntry(
            command: 'shutdown',
            description: l10n.repeater_cliHelpPowerOff,
          ),
        ],
      ),
    ];
  }

  /// Cycles the size-toggle action through the 3 stops: default -> max ->
  /// full -> back to default. The button that calls this never disappears
  /// from the header — unlike the old 2-state design, every stop has a
  /// forward action, there is no state with no size action at all.
  void _cycleSize() {
    final next = (_sizeState + 1) % _sheetStops.length;
    _sheetController.animateTo(
      _sheetStops[next],
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
    setState(() => _sizeState = next);
  }

  Future<void> _jumpToGroup(String label) async {
    // DraggableScrollableSheet pins the inner ListView's maxScrollExtent to
    // 0 while the sheet is below maxChildSize — the content literally
    // cannot scroll below full extent, by design (drag first resizes the
    // sheet, only then scrolls content). So a jump must expand to
    // fullscreen first, or every group past the one already onscreen is an
    // unreachable no-op — which is exactly the "only Info works" bug.
    if (_sheetController.size < 0.999) {
      await _sheetController.animateTo(
        1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      // Let the now-fullscreen sheet's ListView pick up its real (non-zero)
      // scroll extent before computing where to scroll it to.
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;

    final targetContext = _groupKeys[label]?.currentContext;
    final controller = _activeScrollController;
    if (targetContext == null || controller == null || !controller.hasClients) {
      return;
    }
    // targetContext is re-fetched via the GlobalKey above, after the
    // `mounted` guard — it is never the pre-await State.context.
    // ignore: use_build_context_synchronously
    final targetBox = targetContext.findRenderObject() as RenderBox?;
    if (targetBox == null) return;
    // Scrollable.ensureVisible() is a no-op once the target is already
    // partially onscreen — with dense chip rows several groups can be
    // simultaneously visible, so jump taps on anything but the very first
    // group silently did nothing. getOffsetToReveal() always computes the
    // "align target's top edge to the viewport's top" offset unconditionally,
    // which is what a jumpbar needs.
    final viewport = RenderAbstractViewport.of(targetBox);
    final revealOffset = viewport.getOffsetToReveal(targetBox, 0.0).offset;
    final clamped = revealOffset.clamp(
      controller.position.minScrollExtent,
      controller.position.maxScrollExtent,
    );
    await controller.animateTo(
      clamped,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    final groups = _buildGroups(l10n);
    for (final group in groups) {
      _groupKeys.putIfAbsent(group.label, () => GlobalKey());
    }
    final totalCommands = groups.fold<int>(
      0,
      (sum, g) => sum + g.entries.length,
    );

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _sheetStops[0],
      minChildSize: _sheetStops[0],
      maxChildSize: _sheetStops[2],
      snap: true,
      snapSizes: _sheetStops,
      expand: false,
      builder: (context, scrollController) {
        _activeScrollController = scrollController;
        return Container(
          color: t.bg1,
          child: Column(
            children: [
              _buildHeaderBar(context, l10n, t, totalCommands, groups.length),
              DottedSeparator(color: t.line),
              _buildJumpBar(context, t, groups),
              DottedSeparator(color: t.line),
              Expanded(
                // A ListView virtualizes: children (and their GlobalKeys)
                // outside the viewport + cacheExtent are never built, so a
                // jump target's currentContext was null until the list had
                // already scrolled near it — an unsolvable chicken-and-egg
                // for jump-to-group. With only ~129 short entries total,
                // eagerly building everything via SingleChildScrollView is
                // cheap and guarantees every group's key is always mounted.
                child: SingleChildScrollView(
                  key: const Key('repeaterCommandDrawerContentScroll'),
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    t.spacingSm,
                    // Was spacingXs(16) here + spacingSm(13) again from the
                    // first group's own top margin below = 29px total gap
                    // under the jumpbar — way looser than every other tight
                    // row in this drawer (6px). spacingXxs matches that
                    // rhythm; the first group's own top margin is skipped
                    // entirely below so nothing re-adds the old 13px.
                    t.spacingXxs,
                    t.spacingSm,
                    // Bottom breathing room so the last group's chips clear
                    // the sheet edge / gesture nav bar instead of being cut
                    // off flush against it.
                    t.spacingLg + MediaQuery.of(context).padding.bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < groups.length; i++)
                        _buildGroupSection(
                          context,
                          t,
                          groups[i],
                          isFirst: i == 0,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBar(
    BuildContext context,
    AppLocalizations l10n,
    MeshTokens t,
    int totalCommands,
    int groupCount,
  ) {
    // Size-cycle action: label/glyph depend on _sizeState, but the action
    // itself is ALWAYS present — unlike the old design, there is no state
    // where the drawer offers no way to change size. A separate "collapse"
    // link (dismiss the whole drawer) stays available alongside it at every
    // stop too.
    final String sizeGlyph;
    final String sizeLabel;
    switch (_sizeState) {
      case 0:
        sizeGlyph = '⛶';
        sizeLabel = l10n.repeater_commandsExpandAction;
        break;
      case 1:
        sizeGlyph = '⛶';
        sizeLabel = l10n.repeater_commandsFullscreenAction;
        break;
      default:
        sizeGlyph = '⌄';
        sizeLabel = l10n.repeater_commandsCollapseToPanelAction;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingSm,
        vertical: t.spacingXs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '⌘ ${l10n.repeater_commandsListTitle.toUpperCase()}',
                  style: t
                      .monoCaption(color: t.primary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(width: t.spacingXs),
                Flexible(
                  child: Text(
                    '$totalCommands · $groupCount ${l10n.repeater_commandsGroupsSuffix}',
                    style: t.monoCaption(color: t.ink4),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: t.spacingXs),
          _headerActionLink(t, '$sizeGlyph $sizeLabel', _cycleSize),
          Text(' · ', style: t.monoCaption(color: t.ink4)),
          _headerActionLink(
            t,
            '⌄ ${l10n.repeater_commandsCollapseAction}',
            () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _headerActionLink(MeshTokens t, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(label, style: t.monoCaption(color: t.ink4)),
    );
  }

  Widget _buildJumpBar(
    BuildContext context,
    MeshTokens t,
    List<_CommandGroup> groups,
  ) {
    return Container(
      // Without an explicit width, a Container wrapping a horizontally
      // scrolling child shrink-wraps to the chip row's own content width
      // instead of filling the sheet — which left the dotted separator
      // below it short of the trailing edge.
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: t.spacingSm,
        vertical: t.spacingXxs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final group in groups)
              Padding(
                padding: EdgeInsets.only(right: t.spacingXs),
                child: ActionChip(
                  label: Text(
                    group.label,
                    style: t.monoCaption(color: t.primary),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _jumpToGroup(group.label),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    MeshTokens t,
    _CommandGroup group, {
    required bool isFirst,
  }) {
    return Padding(
      key: _groupKeys[group.label],
      // The first group needs no extra top margin — the scroll view's own
      // padding (spacingXxs) already sets the gap under the jumpbar; adding
      // spacingSm again here just for the first group reintroduces the
      // over-loose gap this padding pass fixed.
      padding: EdgeInsets.only(top: isFirst ? 0 : t.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.label,
            style: t
                .monoCaption(color: t.primary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: t.spacingXs),
          _buildCommandGrid(context, t, group.entries),
        ],
      ),
    );
  }

  /// 3 equal-width columns, wrapping to 2 on a narrow sheet/screen — a real
  /// grid (via Expanded cells), not a Wrap, so every chip in a row shares
  /// the same width regardless of its text length.
  Widget _buildCommandGrid(
    BuildContext context,
    MeshTokens t,
    List<_CommandHelpEntry> entries,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 380 ? 2 : 3;
        final rows = <Widget>[];
        for (var i = 0; i < entries.length; i += columns) {
          final rowEntries = entries.skip(i).take(columns).toList();
          rows.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: i + columns < entries.length ? t.spacingXs : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < columns; j++) ...[
                      if (j > 0) SizedBox(width: t.spacingXs),
                      Expanded(
                        child: j < rowEntries.length
                            ? _buildCommandChip(context, t, rowEntries[j])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  Widget _buildCommandChip(
    BuildContext context,
    MeshTokens t,
    _CommandHelpEntry entry,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(t.sm),
      onTap: () {
        if (commandTemplateHasPlaceholder(entry.command)) {
          // Needs values first — the popup itself calls onCommandSelected
          // once the user taps Send; the drawer stays open underneath it
          // exactly like the no-placeholder path below.
          showRepeaterCommandParamPopup(
            context,
            template: entry.command,
            onSend: widget.onCommandSelected,
          );
        } else {
          // No placeholder to fill in — send immediately. The drawer is
          // NOT dismissed here (no Navigator.pop): the terminal response
          // appears below while the command list stays open for the next
          // tap, matching the accepted mockup's "keep browsing" behavior.
          widget.onCommandSelected(entry.command);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: t.spacingSm,
          vertical: t.spacingXs,
        ),
        decoration: BoxDecoration(
          color: t.primaryBg,
          border: Border.all(color: t.primaryLine),
          borderRadius: BorderRadius.circular(t.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Long commands (e.g. "set radio {freq},{bw},{sf},{cr}") must
            // stay fully readable, so this wraps across lines instead of
            // sitting in a fixed-size Row that would overflow the chip.
            Text.rich(
              TextSpan(
                style: t
                    .monoCaption(color: t.primary)
                    .copyWith(fontWeight: FontWeight.w600),
                children: [
                  TextSpan(text: entry.command),
                  if (entry.serialOnly)
                    TextSpan(
                      text: ' ⚷',
                      style: t.monoCaption(color: t.warn),
                    ),
                ],
              ),
            ),
            Text(
              entry.description,
              style: t.monoCaption(color: t.ink4),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
