package com.saadm.bloop

import android.app.AppOpsManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
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
							// With the package URI the system opens Bloop's own toggle;
							// without it the user lands on a list of every app.
							val intent = Intent(
								Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
								Uri.parse("package:$packageName")
							)
							openSettingsAndReturn(intent, "android:schedule_exact_alarm") {
								canScheduleExactAlarms()
							}
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
									// A second request replaces the first; answer the first now so
									// its caller is not left waiting.
									pendingPermissionResult?.success(false)
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
							openSettingsAndReturn(intent, "android:post_notification") {
								NotificationManagerCompat.from(this).areNotificationsEnabled()
							}
							result.success(true)
						} catch (e: Exception) {
							result.error("ERROR", e.message, null)
						}
					}
					else -> result.notImplemented()
				}
			}
	}

	private var permissionWatcher: AppOpsManager.OnOpChangedListener? = null
	private val handler = Handler(Looper.getMainLooper())
	private val stopWatching = Runnable { stopWatchingPermission() }

	private fun canScheduleExactAlarms(): Boolean {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
		val alarmManager = getSystemService(android.content.Context.ALARM_SERVICE) as android.app.AlarmManager
		return alarmManager.canScheduleExactAlarms()
	}

	/**
	 * Opens a system settings page and, once [isGranted] turns true, brings Bloop
	 * back to the front so the user doesn't have to find the way back.
	 *
	 * The page is started in Bloop's own task (no NEW_TASK) so that returning
	 * counts as a switch within the foreground task, which Android allows from
	 * the background. If the system still refuses, the user can use back as before.
	 */
	private fun openSettingsAndReturn(intent: Intent, op: String, isGranted: () -> Boolean) {
		stopWatchingPermission()
		startActivity(intent)
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
		try {
			val appOps = getSystemService(android.content.Context.APP_OPS_SERVICE) as AppOpsManager
			val listener = AppOpsManager.OnOpChangedListener { _, _ ->
				handler.post {
					if (isGranted()) {
						stopWatchingPermission()
						bringToFront()
					}
				}
			}
			appOps.startWatchingMode(op, packageName, listener)
			permissionWatcher = listener
			// Don't watch forever if the user wanders off.
			handler.postDelayed(stopWatching, 5 * 60 * 1000L)
		} catch (e: Exception) {
			Log.w(CHANNEL, "openSettingsAndReturn: not watching $op: ${e.message}")
		}
	}

	private fun stopWatchingPermission() {
		handler.removeCallbacks(stopWatching)
		val listener = permissionWatcher ?: return
		permissionWatcher = null
		try {
			(getSystemService(android.content.Context.APP_OPS_SERVICE) as AppOpsManager).stopWatchingMode(listener)
		} catch (e: Exception) {
			Log.w(CHANNEL, "stopWatchingPermission: ${e.message}")
		}
	}

	private fun bringToFront() {
		val intent = Intent(this, MainActivity::class.java)
		intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
		startActivity(intent)
	}

	override fun onDestroy() {
		stopWatchingPermission()
		super.onDestroy()
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
