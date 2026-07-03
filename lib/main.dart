/// iConvert · 全格式转换器（侧载版）
///
/// 纯 Flutter 实现，无任何平台原生代码。
/// 设计：iOS Cupertino 风格，液态玻璃仅用于 4 类关键弹窗。
///
/// 入口装配：
/// - CupertinoApp + CupertinoThemeData
/// - MultiProvider 注册全局状态
/// - 启动页 SplashScreen（毛玻璃 + 图标脉冲 + 进度文字）
/// - 启动页结束后跳转 HomePage
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:iconvert/models/conversion_model.dart';
import 'package:iconvert/models/history_model.dart';
import 'package:iconvert/pages/splash_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 锁定竖屏（媒体转换器不需要横屏）
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const IConvertApp());
}

class IConvertApp extends StatelessWidget {
  const IConvertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConversionModel>(
          create: (_) => ConversionModel(),
        ),
        ChangeNotifierProvider<HistoryModel>(
          create: (_) => HistoryModel()..load(),
        ),
      ],
      child: CupertinoApp(
        title: 'iConvert',
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: Color(0xFF007AFF),
          scaffoldBackgroundColor: Color(0xFFF2F2F7),
          barBackgroundColor: Color(0xFFF8F8F8),
          textTheme: CupertinoTextThemeData(
            primaryColor: Color(0xFF007AFF),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}