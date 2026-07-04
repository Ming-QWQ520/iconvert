/// iConvert · 全格式转换器（侧载版）
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/history_model.dart';
import 'package:iconvert/pages/splash_page.dart';
import 'package:iconvert/services/foreground_service.dart';
import 'package:iconvert/services/file_service.dart';
import 'package:iconvert/widgets/glass_theme.dart';

bool gQuickActionStartConversion = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  ForegroundService.init();
  FileService.cleanupTempFiles();

  const quickActions = QuickActions();
  quickActions.initialize((shortcutType) {
    if (shortcutType == 'action_start_conversion') {
      gQuickActionStartConversion = true;
    }
  });
  quickActions.setShortcutItems(const [
    ShortcutItem(type: 'action_start_conversion', localizedTitle: '开始转换', icon: 'ic_launcher'),
  ]);

  runApp(const IConvertApp());
}

class IConvertApp extends StatelessWidget {
  const IConvertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConversionModel>(create: (_) => ConversionModel()),
        ChangeNotifierProvider<HistoryModel>(create: (_) => HistoryModel()..load()),
        ChangeNotifierProvider<GlassProvider>(create: (_) => GlassProvider()..load()),
      ],
      child: Consumer<GlassProvider>(
        builder: (context, glass, child) {
          return CupertinoApp(
            title: 'iConvert',
            debugShowCheckedModeBanner: false,
            theme: CupertinoThemeData(
              brightness: Brightness.light,
              primaryColor: const Color(0xFF007AFF),
              // 开启液态玻璃：透明背景（让背景图透出）
              // 未开启：白色背景
              scaffoldBackgroundColor: glass.enabled ? const Color(0x00000000) : const Color(0xFFF2F2F7),
              barBackgroundColor: glass.enabled ? const Color(0x00000000) : const Color(0xFFF8F8F8),
              textTheme: const CupertinoTextThemeData(primaryColor: Color(0xFF007AFF)),
            ),
            builder: (context, child) {
              return GlassBackground(child: child!);
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
