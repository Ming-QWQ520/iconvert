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

/// 全局快捷动作回调（从 quick_actions 触发）
/// 在 splash_page 中检查此标志，如果为 true 则自动跳过启动页直接进入主页
bool gQuickActionStartConversion = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 初始化前台服务
  ForegroundService.init();

  // 清理上次运行遗留的临时文件（避免缓存爆炸）
  FileService.cleanupTempFiles();

  // 初始化桌面快捷动作
  const quickActions = QuickActions();
  quickActions.initialize((shortcutType) {
    if (shortcutType == 'action_start_conversion') {
      gQuickActionStartConversion = true;
    }
  });
  // 设置快捷动作列表
  quickActions.setShortcutItems(const [
    ShortcutItem(
      type: 'action_start_conversion',
      localizedTitle: '开始转换',
      icon: 'ic_launcher',
    ),
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
      ],
      child: CupertinoApp(
        title: 'iConvert',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: Color(0xFF007AFF),
          scaffoldBackgroundColor: Color(0xFFF2F2F7),
          barBackgroundColor: Color(0xFFF8F8F8),
          textTheme: CupertinoTextThemeData(primaryColor: Color(0xFF007AFF)),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
