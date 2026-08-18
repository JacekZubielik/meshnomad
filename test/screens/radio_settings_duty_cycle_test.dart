import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:meshnomad/connector/meshcore_connector.dart';
import 'package:meshnomad/screens/settings_screen.dart';
import 'package:meshnomad/services/app_settings_service.dart';
import 'package:meshnomad/storage/prefs_manager.dart';

class _CliCapturingConnector extends MeshCoreConnector {
  final List<String> cliCommands = [];

  @override
  Future<void> sendCliCommand(String command) async {
    cliCommands.add(command);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettingsService settings;
  late _CliCapturingConnector connector;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrefsManager.reset();
    await PrefsManager.initialize();
    settings = AppSettingsService();
    await settings.loadSettings();
    connector = _CliCapturingConnector();
    addTearDown(connector.dispose);
  });

  test('persists the chosen percent app-side and forwards it to the node '
      'over the self-CLI', () async {
    await applyDutyCycleToNode(
      percent: 25,
      settings: settings,
      connector: connector,
    );

    expect(settings.settings.txDutyCyclePercent, 25);
    expect(connector.cliCommands, ['set dutycycle 25']);
  });

  test('full range stays available — 1 and 100 both pass through', () async {
    await applyDutyCycleToNode(
      percent: 1,
      settings: settings,
      connector: connector,
    );
    await applyDutyCycleToNode(
      percent: 100,
      settings: settings,
      connector: connector,
    );

    expect(settings.settings.txDutyCyclePercent, 100);
    expect(connector.cliCommands, ['set dutycycle 1', 'set dutycycle 100']);
  });
}
