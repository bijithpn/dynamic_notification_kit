package com.intersmart.dynamic_notification_kit

import android.Manifest
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

@Suppress("UNCHECKED_CAST")
class DynamicNotificationKitPlugin :
    FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware,
    PluginRegistry.RequestPermissionsResultListener, EventChannel.StreamHandler {

    private lateinit var channel: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var ctx: Context
    private var engine: NotificationEngine? = null
    private var activity: Activity? = null
    private var binding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        ctx = b.applicationContext
        channel = MethodChannel(b.binaryMessenger, "dynamic_notification_kit").also { it.setMethodCallHandler(this) }
        events = EventChannel(b.binaryMessenger, "dynamic_notification_kit/events").also { it.setStreamHandler(this) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }

    private fun eng(): NotificationEngine = engine ?: NotificationEngine(ctx).also { engine = it }

    private fun permitted(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            val args = (call.arguments as? Map<String, Any?>) ?: emptyMap()
            when (call.method) {
                "getCapabilities" -> result.success(capabilities())
                "diagnose" -> result.success(diagnose())
                "openSettings" -> { openSettings(args["promoted"] == true); result.success(null) }
                "requestPermission" -> requestPermission(result)
                "startDelivery", "updateDelivery" -> {
                    if (!guard(result)) return
                    eng().postDelivery(args)
                    if (call.method == "startDelivery") emit("started", args["id"] as? String)
                    result.success(null)
                }
                "start", "update" -> {
                    if (!guard(result)) return
                    when (args["mode"]) {
                        "minimal" -> eng().postMinimal(args)
                        else -> eng().postStandard(args)
                    }
                    result.success(null)
                }
                "end" -> {
                    val id = args["id"] as String
                    eng().cancel(id)
                    emit("ended", id)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("platform", e.message ?: e.toString(), null)
        }
    }

    private fun guard(result: MethodChannel.Result): Boolean {
        if (!permitted()) {
            result.error("permissionDenied", "POST_NOTIFICATIONS not granted", null)
            return false
        }
        return true
    }

    private fun capabilities(): Map<String, Any?> {
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val e = eng()
        return mapOf(
            "platform" to "android",
            "osVersion" to Build.VERSION.SDK_INT.toString(),
            "notificationsPermitted" to (permitted() && nm.areNotificationsEnabled()),
            "supportsLiveSurface" to (Build.VERSION.SDK_INT >= 36),
            "supportsPromotedOngoing" to e.canPromote(),
            "supportsDynamicIsland" to false,
            "dynamicIslandIsHeuristic" to false,
        )
    }

    private fun diagnose(): List<String> {
        val out = mutableListOf<String>()
        val info = ctx.packageManager.getPackageInfo(ctx.packageName, PackageManager.GET_PERMISSIONS)
        val perms = info.requestedPermissions?.toSet() ?: emptySet()
        if (Build.VERSION.SDK_INT >= 33 && "android.permission.POST_NOTIFICATIONS" !in perms)
            out += "AndroidManifest.xml is missing POST_NOTIFICATIONS (run: dart run dynamic_notification_kit:setup --android)"
        if (Build.VERSION.SDK_INT >= 36 && "android.permission.POST_PROMOTED_NOTIFICATIONS" !in perms)
            out += "AndroidManifest.xml is missing POST_PROMOTED_NOTIFICATIONS; Live Updates chip will not show"
        if (Build.VERSION.SDK_INT >= 36 && !eng().canPromote())
            out += "Live Updates are switched off for this app. Enable: Settings > Notifications > this app > Live notifications"
        return out
    }

    private fun openSettings(promoted: Boolean) {
        val flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
        val pkg = ctx.packageName
        val intents = buildList {
            if (promoted && Build.VERSION.SDK_INT >= 36)
                add(android.content.Intent("android.settings.MANAGE_APP_PROMOTED_NOTIFICATIONS")
                    .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, pkg))
            add(android.content.Intent(android.provider.Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(android.provider.Settings.EXTRA_APP_PACKAGE, pkg))
        }
        for (i in intents) {
            try { (activity ?: ctx).startActivity(i.addFlags(flags)); return } catch (_: Exception) {}
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (permitted()) return result.success(true)
        val a = activity ?: return result.error("unsupported", "No foreground activity", null)
        pendingPermission = result
        ActivityCompat.requestPermissions(a, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ)
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, res: IntArray): Boolean {
        if (code != REQ) return false
        pendingPermission?.success(res.isNotEmpty() && res[0] == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
        return true
    }

    private fun emit(type: String, id: String?) {
        main.post { sink?.success(mapOf("type" to type, "id" to id)) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) { sink = null }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        activity = b.activity; binding = b; b.addRequestPermissionsResultListener(this)
    }
    override fun onDetachedFromActivity() {
        binding?.removeRequestPermissionsResultListener(this); binding = null; activity = null
    }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    companion object { private const val REQ = 7421 }
}
