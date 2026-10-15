package com.omaribrahim.app_icon_switcher

import android.content.ComponentName
import android.content.Context
import android.content.pm.ActivityInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Switches the launcher icon by enabling one `<activity-alias>` of the app and
 * disabling the others.
 */
class AppIconSwitcherPlugin :
    FlutterPlugin,
    MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "app_icon_switcher")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "isSupported" -> result.success(true)
                "getCurrentIcon" -> {
                    val aliases = call.argument<List<String>>("androidAliases")
                    result.success(currentAlias(aliases))
                }
                "setIcon" -> {
                    val alias = call.argument<String>("androidAlias")
                    if (alias.isNullOrEmpty()) {
                        result.error("bad_args", "androidAlias is required", null)
                        return
                    }
                    val aliases = call.argument<List<String>>("androidAliases") ?: emptyList()
                    setAlias(alias, aliases)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("app_icon_switcher_failed", e.message ?: e.toString(), null)
        }
    }

    /**
     * Every activity-alias declared in this app, by simple name (the part after
     * the last dot) to full class name. Matching by simple name means aliases
     * work even when the applicationId differs from the manifest namespace.
     */
    private fun declaredAliases(): Map<String, String> {
        val pm = context.packageManager
        val flags = PackageManager.GET_ACTIVITIES or PackageManager.MATCH_DISABLED_COMPONENTS
        val info = if (Build.VERSION.SDK_INT >= 33) {
            pm.getPackageInfo(context.packageName, PackageManager.PackageInfoFlags.of(flags.toLong()))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(context.packageName, flags)
        }
        return info.activities.orEmpty()
            .filter { it.targetActivity != null }
            .associate { it.name.substringAfterLast('.') to it.name }
    }

    private fun component(className: String) = ComponentName(context.packageName, className)

    /** The simple name of the first enabled alias, or null. */
    private fun currentAlias(aliases: List<String>?): String? {
        val declared = declaredAliases()
        val names = aliases ?: declared.keys.toList()
        return names.firstOrNull { name ->
            declared[name]?.let { isEnabled(component(it)) } ?: false
        }
    }

    private fun isEnabled(name: ComponentName): Boolean {
        val pm = context.packageManager
        return when (pm.getComponentEnabledSetting(name)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> manifestEnabled(name) ?: false
            else -> false
        }
    }

    /** The manifest's `android:enabled` for [name], or null if it isn't declared. */
    private fun manifestEnabled(name: ComponentName): Boolean? {
        val pm = context.packageManager
        val info: ActivityInfo = try {
            if (Build.VERSION.SDK_INT >= 33) {
                pm.getActivityInfo(
                    name,
                    PackageManager.ComponentInfoFlags.of(PackageManager.MATCH_DISABLED_COMPONENTS.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                pm.getActivityInfo(name, PackageManager.MATCH_DISABLED_COMPONENTS)
            }
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        return info.enabled
    }

    private fun setAlias(alias: String, aliases: List<String>) {
        val pm = context.packageManager
        val declared = declaredAliases()
        val target = declared[alias]?.let { component(it) }
            ?: throw IllegalArgumentException("No activity-alias named $alias in the manifest")
        // Enable the new one first so there is never a moment without a launcher entry.
        pm.setComponentEnabledSetting(
            target,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        for (other in aliases.toSet() - alias) {
            val name = declared[other]?.let { component(it) } ?: continue
            pm.setComponentEnabledSetting(
                name,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
