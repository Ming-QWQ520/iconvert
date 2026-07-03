// 简单冒烟测试：验证 iConvertApp 能构造
import 'package:flutter_test/flutter_test.dart';
import 'package:iconvert/main.dart';

void main() {
  testWidgets('App constructs', (WidgetTester tester) async {
    // 构造 app 实例（不启动）
    const app = IConvertApp();
    expect(app, isNotNull);
  });
}
