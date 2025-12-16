package com.saadm.bloop

import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "bloop/permissions"
	private var pendingPermissionResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"getLocalTimezone" -> {
						try {
							val tz = java.util.TimeZone.getDefault().id
							Log.d(CHANNEL, "getLocalTimezone => $tz")
							result.success(tz)
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					"canScheduleExactAlarm" -> {
						try {
							val alarmManager = getSystemService(android.content.Context.ALARM_SERVICE) as android.app.AlarmManager
							val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
								alarmManager.canScheduleExactAlarms()
							} else {
								true
							}
							Log.d(CHANNEL, "canScheduleExactAlarm => $can")
							result.success(can)
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					"requestExactAlarm" -> {
						try {
							val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
							intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							startActivity(intent)
							// We opened settings for the user; do not assume permission granted yet.
							Log.d(CHANNEL, "requestExactAlarm: opened settings")
							result.success(false)
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					"hasNotificationPermission" -> {
						try {
							if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
								result.success(true)
							} else {
								val has = ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
								Log.d(CHANNEL, "hasNotificationPermission => $has")
								result.success(has)
							}
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					"requestNotificationPermission" -> {
						try {
							if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
								result.success(true)
							} else {
								if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
									result.success(true)
								} else {
									pendingPermissionResult = result
									ActivityCompat.requestPermissions(this, arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1001)
									Log.d(CHANNEL, "requestNotificationPermission: requesting runtime permission")
								}
							}
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					"openNotificationSettings" -> {
						try {
							val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
							intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
							intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
							startActivity(intent)
							result.success(true)
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}

	override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)
		if (requestCode == 1001) {
			val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
				Log.d(CHANNEL, "onRequestPermissionsResult: granted=$granted")
				pendingPermissionResult?.success(granted)
			pendingPermissionResult = null
		}
	}
}
