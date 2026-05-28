import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secure_application/secure_application.dart';
import 'theme/app_theme.dart';
import 'services/vault_session.dart';
import 'screens/splash_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/vault_screen.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/edit_entry_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/chrome_import_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const PassMgrApp());
}

class PassMgrApp extends StatelessWidget {
  const PassMgrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return SecureApplication(
      child: MaterialApp(
        title: 'PassMgr',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
        routes: {
          '/splash':   (_) => const SplashScreen(),
          '/setup':    (_) => const SetupScreen(),
          '/lock':     (_) => const LockScreen(),
          '/vault':    (_) => const VaultScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/import':   (_) => const ChromeImportScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/detail') {
            final entryId = settings.arguments as int;
            return MaterialPageRoute(
              builder: (_) => EntryDetailScreen(entryId: entryId),
            );
          }
          if (settings.name == '/edit') {
            final entryId = settings.arguments as int?;
            return MaterialPageRoute(
              builder: (_) => EditEntryScreen(entryId: entryId),
            );
          }
          return null;
        },
        builder: (context, child) => _LifecycleObserver(child: child!),
      ),
    );
  }
}

class _LifecycleObserver extends StatefulWidget {
  final Widget child;
  const _LifecycleObserver({required this.child});

  @override
  State<_LifecycleObserver> createState() => _LifecycleObserverState();
}

class _LifecycleObserverState extends State<_LifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (VaultSession.instance.isUnlocked && !VaultSession.suppressLock) {
        VaultSession.instance.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
