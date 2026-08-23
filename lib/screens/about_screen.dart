import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/snack_bar_builder.dart';
import '../l10n/l10n.dart';
import '../theme/mesh_tokens.dart';
import '../utils/build_info.dart';
import '../widgets/mesh_dashed_divider.dart';
import '../widgets/mesh_ui.dart';

Future<void> pushAboutScreen(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => const AboutScreen()),
  );
}

const _websiteUrl = 'https://meshnomad.org';
const _docsUrlEn = 'https://meshnomad.org/latest/';
const _docsUrlPl = 'https://meshnomad.org/latest/pl/';
const _repoUrl = 'https://github.com/JacekZubielik/meshnomad';
const _releasesUrl = '$_repoUrl/releases';
const _issuesUrl = '$_repoUrl/issues/new';

/// App version, build provenance, project links and legal — its own screen,
/// matching the App Settings navigation pattern (expanded 2026-08-23 now
/// that meshnomad.org is live).
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appVersion = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  String get _versionLabel {
    if (_appVersion.isEmpty) return '';
    return _buildNumber.isEmpty ? _appVersion : '$_appVersion ($_buildNumber)';
  }

  String _buildSourceLabel(BuildContext context) => BuildInfo.isCi
      ? context.l10n.about_buildSourceCi
      : context.l10n.about_buildSourceLocal;

  Future<void> _copyVersionInfo(BuildContext context) async {
    final l10n = context.l10n;
    final lines = <String>[
      '${l10n.appTitle} $_versionLabel',
      if (BuildInfo.hasDetails) ...[
        'commit: ${BuildInfo.gitSha}${BuildInfo.gitDirty ? ' (modified)' : ''}',
        'branch: ${BuildInfo.gitBranch}',
        'built: ${BuildInfo.buildTime}',
        'source: ${BuildInfo.buildSource}',
      ],
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!context.mounted) return;
    showDismissibleSnackBar(
      context,
      content: Text(l10n.about_versionCopied),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    // 07-selection-bugs.md: SelectionArea scoped per-screen (not globally
    // above the Navigator) so "select all" can't sweep in text from other,
    // offstage routes still mounted via maintainState:true.
    return SelectionArea(child: _screenBody(context));
  }

  Widget _screenBody(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings_about), centerTitle: true),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(t.spacingMd),
          children: [
            _buildAppCard(context),
            SizedBox(height: t.spacingSm),
            _buildLinksCard(context),
            SizedBox(height: t.spacingSm),
            _buildLegalCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MeshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.appTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: l10n.about_copyVersionTooltip,
                icon: const Icon(Icons.copy_outlined, size: 20),
                color: t.primary,
                onPressed: () => _copyVersionInfo(context),
              ),
            ],
          ),
          Text(
            l10n.settings_aboutVersion(
              _versionLabel.isEmpty ? l10n.common_loading : _versionLabel,
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: t.spacingMd),
          Text(l10n.settings_aboutDescription),
          if (BuildInfo.hasDetails) ...[
            SizedBox(height: t.spacingSm),
            const MeshDashedDivider(),
            SizedBox(height: t.spacingSm),
            Text(
              l10n.about_buildDetails,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: t.spacingXs),
            _buildDetailRow(
              context,
              l10n.about_buildCommit,
              BuildInfo.gitDirty
                  ? '${BuildInfo.gitSha} (${l10n.about_buildModified})'
                  : BuildInfo.gitSha,
            ),
            _buildDetailRow(
              context,
              l10n.about_buildBranch,
              BuildInfo.gitBranch,
            ),
            _buildDetailRow(context, l10n.about_buildDate, BuildInfo.buildTime),
            _buildDetailRow(
              context,
              l10n.about_buildSource,
              _buildSourceLabel(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.spacingXxs / 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Text(value, style: t.monoCaption(color: scheme.onSurface)),
        ],
      ),
    );
  }

  Widget _buildLinksCard(BuildContext context) {
    final l10n = context.l10n;
    final docsUrl = Localizations.localeOf(context).languageCode == 'pl'
        ? _docsUrlPl
        : _docsUrlEn;
    return MeshCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SettingsTappableTile(
            icon: Icons.public,
            title: l10n.about_website,
            subtitle: _websiteUrl,
            onTap: () => _open(_websiteUrl),
          ),
          const MeshDashedDivider(indent: 16),
          SettingsTappableTile(
            icon: Icons.menu_book_outlined,
            title: l10n.about_documentation,
            subtitle: docsUrl,
            onTap: () => _open(docsUrl),
          ),
          const MeshDashedDivider(indent: 16),
          SettingsTappableTile(
            icon: Icons.new_releases_outlined,
            title: l10n.about_releaseNotes,
            subtitle: _releasesUrl,
            onTap: () => _open(_releasesUrl),
          ),
          const MeshDashedDivider(indent: 16),
          SettingsTappableTile(
            icon: Icons.code,
            title: l10n.about_sourceCode,
            subtitle: _repoUrl,
            onTap: () => _open(_repoUrl),
          ),
          const MeshDashedDivider(indent: 16),
          SettingsTappableTile(
            icon: Icons.bug_report_outlined,
            title: l10n.about_reportIssue,
            subtitle: _issuesUrl,
            onTap: () => _open(_issuesUrl),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalCard(BuildContext context) {
    final l10n = context.l10n;
    final t = MeshTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return MeshCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settings_aboutLegalese,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          SizedBox(height: t.spacingSm),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              // Plain action button, not a switch-style control — never
              // renders the app-wide buttonBorder style.
              style: const ButtonStyle(
                side: WidgetStatePropertyAll(BorderSide.none),
              ),
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: _versionLabel,
              ),
              child: Text(l10n.about_openSourceLicenses),
            ),
          ),
        ],
      ),
    );
  }
}
