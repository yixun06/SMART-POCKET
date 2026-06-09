package com.example.smart_pocket

import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
 
class MainActivity : FlutterFragmentActivity() {
	private var screenCaptureCallback: Any? = null
	private var screenCaptureChannel: MethodChannel? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		GeneratedPluginRegistrant.registerWith(flutterEngine)

		screenCaptureChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			"smart_pocket/screen_capture",
		)

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
			try {
				val callbackClass = Class.forName("android.window.ScreenCaptureCallback")
				val proxy = java.lang.reflect.Proxy.newProxyInstance(
					callbackClass.classLoader,
					arrayOf(callbackClass),
					java.lang.reflect.InvocationHandler { _, method, _ ->
						if (method.name == "onScreenCaptured") {
							screenCaptureChannel?.invokeMethod("screenCaptureDetected", null)
						}
						null
					}
				)
				screenCaptureCallback = proxy
				val registerMethod = javaClass.getMethod(
					"registerScreenCaptureCallback",
					java.util.concurrent.Executor::class.java,
					callbackClass
				)
				registerMethod.invoke(this, mainExecutor, screenCaptureCallback)
			} catch (e: Exception) {
				// No-op if the platform class/method isn't available at compile time
			}
		}
	}

	override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
			screenCaptureCallback?.let {
				try {
					val callbackClass = Class.forName("android.window.ScreenCaptureCallback")
					val unregisterMethod = javaClass.getMethod("unregisterScreenCaptureCallback", callbackClass)
					unregisterMethod.invoke(this, it)
				} catch (e: Exception) {
					// ignore
				}
			}
			screenCaptureCallback = null
		}
		screenCaptureChannel = null
		super.cleanUpFlutterEngine(flutterEngine)
	}
}
