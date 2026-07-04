/// iConvert · 全格式转换器（侧载版）
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/history_model.dart';
import 'package:iconvert/pages/splash_page.dart';
import 'package:iconvert/services/foreground_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 初始化前台服务（用于后台转换时显示通知栏进度）
  ForegroundService.init();

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
