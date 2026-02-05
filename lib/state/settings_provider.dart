import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_controller.dart';
import 'settings_models.dart';

final settingsProvider = settingsControllerProvider;

typedef SettingsNotifier = SettingsController;
typedef SettingsViewState = SettingsState;
