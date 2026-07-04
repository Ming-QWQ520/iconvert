package com.iconvert.iconvert

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 注册 flutter_foreground_task 的 background service
        FlutterForegroundTaskPlugin.addTaskObserver(flutterEngine)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterForegroundTaskPlugin.removeTaskObserver(flutterEngine)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
