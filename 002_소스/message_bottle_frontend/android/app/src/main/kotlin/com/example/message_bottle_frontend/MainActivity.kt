package com.example.message_bottle_frontend

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 앱이 기기의 네트워크 연결(Wi-Fi·데이터) 여부를 묻는 통로. lib/network_guard.dart 참고.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "message_bottle/network")
            .setMethodCallHandler { call, result ->
                if (call.method == "isOnline") result.success(isOnline()) else result.notImplemented()
            }
    }

    /** 지금 쓸 수 있는 네트워크가 하나라도 있으면 true. 인터넷이 없는 LAN(Wi-Fi)도 연결된 것으로 본다. */
    private fun isOnline(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) ||
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
    }
}
