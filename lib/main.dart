import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'screens/home_shell.dart';
import 'services/notifications.dart';
import 'state/app_state.dart';
import 'state/settings_store.dart';
import 'theme/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.instance.init().catchError((_) {});
  runApp(const MoneyApp());
}

class MoneyApp extends StatefulWidget {
  const MoneyApp({super.key});

  @override
  State<MoneyApp> createState() => _MoneyAppState();
}

class _MoneyAppState extends State<MoneyApp> {
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    appState = AppState(Repository(AppDatabase()), SettingsStore());
    appState.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(value: appState, child: const _Root());
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.loaded) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    final strings = state.strings;
    final themeMode = themeModeFrom(state.settings.theme);
    final locale = Locale(strings.lang);
    return MaterialApp(
      title: strings.tr('app_name'),
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: strings.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
            child: child!,
          ),
        );
      },
      home: const HomeShell(),
    );
  }
}