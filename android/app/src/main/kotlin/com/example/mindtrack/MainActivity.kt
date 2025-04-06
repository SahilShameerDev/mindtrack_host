package com.example.mindtrack

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*
import kotlin.collections.HashMap

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.screen_time_tracker/screen_time"
    private val TAG = "ScreenTimeTracker"
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "checkUsageStatsPermission" -> {
                        result.success(hasUsageStatsPermission())
                    }
                    "openUsageStatsSettings" -> {
                        // Open usage access settings
                        Log.d(TAG, "Opening usage stats settings")
                        openUsageStatsSettings()
                        result.success(null) // No direct result, user needs to grant manually
                    }
                    "getScreenTimeData" -> {
                        if (hasUsageStatsPermission()) {
                            val data = getScreenTimeData()
                            Log.d(TAG, "Data fetched: $data")
                            result.success(data)
                        } else {
                            Log.e(TAG, "Permission denied for usage stats")
                            result.error("PERMISSION_DENIED", "Usage stats permission not granted", null)
                        }
                    }
                    "getPhoneUnlockCount" -> {
                        if (hasUsageStatsPermission()) {
                            val unlockCount = getPhoneUnlockCount()
                            Log.d(TAG, "Unlock count: $unlockCount")
                            result.success(unlockCount)
                        } else {
                            Log.e(TAG, "Permission denied for usage stats")
                            result.error("PERMISSION_DENIED", "Usage stats permission not granted", null)
                        }
                    }
                    else -> {
                        Log.e(TAG, "Method not implemented: ${call.method}")
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in method channel: ${e.message}", e)
                result.error("EXCEPTION", "Exception: ${e.message}", e.stackTraceToString())
            }
        }
    }
    
    private fun hasUsageStatsPermission(): Boolean {
        try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName
                )
            }
            val hasPermission = mode == AppOpsManager.MODE_ALLOWED
            Log.d(TAG, "Has usage stats permission: $hasPermission")
            return hasPermission
        } catch (e: Exception) {
            Log.e(TAG, "Error checking permission: ${e.message}", e)
            return false
        }
    }
    
    private fun getPhoneUnlockCount(): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            val startTime = calendar.timeInMillis
            
            val endTime = System.currentTimeMillis()
            Log.d(TAG, "Getting unlock count from $startTime to $endTime")
            
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            
            var unlockCount = 0
            val hourlyUnlocks = HashMap<Int, Int>()
            
            // Initialize hourly buckets with zeros
            for (hour in 0..23) {
                hourlyUnlocks[hour] = 0
            }
            
            if (usageEvents.hasNextEvent()) {
                val event = UsageEvents.Event()
                
                while (usageEvents.hasNextEvent()) {
                    usageEvents.getNextEvent(event)
                    
                    // Check for screen unlock events
                    if (event.eventType == UsageEvents.Event.KEYGUARD_HIDDEN) {
                        unlockCount++
                        
                        // Get hour of the day for this unlock
                        val unlockTime = Calendar.getInstance()
                        unlockTime.timeInMillis = event.timeStamp
                        val hourOfDay = unlockTime.get(Calendar.HOUR_OF_DAY)
                        
                        // Increment the count for this hour
                        hourlyUnlocks[hourOfDay] = (hourlyUnlocks[hourOfDay] ?: 0) + 1
                    }
                }
            } else {
                Log.w(TAG, "No usage events found")
            }
            
            result["totalUnlocks"] = unlockCount
            
            // Convert hourly unlocks to a list format for Flutter
            val hourlyUnlocksList = ArrayList<HashMap<String, Any>>()
            for (hour in 0..23) {
                val hourData = HashMap<String, Any>()
                hourData["hour"] = hour
                hourData["count"] = hourlyUnlocks[hour] ?: 0
                hourlyUnlocksList.add(hourData)
            }
            result["hourlyUnlocks"] = hourlyUnlocksList
            
            Log.d(TAG, "Unlock count: $unlockCount")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting unlock count: ${e.message}", e)
            result["totalUnlocks"] = 0
            result["hourlyUnlocks"] = ArrayList<HashMap<String, Any>>()
            result["error"] = "Error: ${e.message}"
        }
        
        return result
    }
    
    private fun getScreenTimeData(): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        val appUsage = ArrayList<HashMap<String, Any>>()
        
        try {
            val calendar = Calendar.getInstance()
            calendar.set(Calendar.HOUR_OF_DAY, 0)
            calendar.set(Calendar.MINUTE, 0)
            calendar.set(Calendar.SECOND, 0)
            calendar.set(Calendar.MILLISECOND, 0)
            val startTime = calendar.timeInMillis
            
            val endTime = System.currentTimeMillis()
            Log.d(TAG, "Getting usage stats from $startTime to $endTime")
            
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            
            // First try the events method
            val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
            
            val appUsageMap = HashMap<String, HashMap<String, Any>>()
            var totalScreenTime = 0L
            
            // Check if we have any events at all
            if (!usageEvents.hasNextEvent()) {
                Log.w(TAG, "No usage events found, trying usage stats approach")
                
                // Fallback to usage stats when events are not available (common in some devices)
                val stats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                
                if (stats != null && stats.isNotEmpty()) {
                    for (usageStats in stats) {
                        val packageName = usageStats.packageName
                        val totalTimeInForeground = usageStats.totalTimeInForeground
                        
                        if (totalTimeInForeground > 0) {
                            totalScreenTime += totalTimeInForeground
                            
                            try {
                                val packageManager = packageManager
                                val appName = try {
                                    val appInfo = packageManager.getApplicationInfo(packageName, 0)
                                    packageManager.getApplicationLabel(appInfo).toString()
                                } catch (e: Exception) {
                                    packageName
                                }
                                
                                appUsageMap[packageName] = hashMapOf(
                                    "packageName" to packageName,
                                    "appName" to appName as Any,
                                    "usageTime" to totalTimeInForeground
                                )
                            } catch (e: Exception) {
                                Log.e(TAG, "Error processing package $packageName: ${e.message}")
                            }
                        }
                    }
                } else {
                    Log.w(TAG, "No usage stats found either")
                }
            } else {
                // Process events as before
                val event = UsageEvents.Event()
                var currentApp = ""
                var lastEventTime = 0L
                
                while (usageEvents.hasNextEvent()) {
                    usageEvents.getNextEvent(event)
                    
                    if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                        currentApp = event.packageName ?: ""
                        lastEventTime = event.timeStamp
                    } else if (event.eventType == UsageEvents.Event.ACTIVITY_PAUSED && currentApp == event.packageName) {
                        val usageTime = event.timeStamp - lastEventTime
                        
                        if (usageTime > 0 && currentApp.isNotEmpty()) {
                            totalScreenTime += usageTime
                            
                            try {
                                if (!appUsageMap.containsKey(currentApp)) {
                                    val packageManager = packageManager
                                    val appName = try {
                                        val appInfo = packageManager.getApplicationInfo(currentApp, 0)
                                        packageManager.getApplicationLabel(appInfo).toString()
                                    } catch (e: Exception) {
                                        currentApp
                                    }
                                    
                                    appUsageMap[currentApp] = hashMapOf(
                                        "packageName" to currentApp,
                                        "appName" to appName as Any,
                                        "usageTime" to 0L
                                    )
                                }
                                
                                val currentUsageTime = appUsageMap[currentApp]!!["usageTime"] as Long
                                appUsageMap[currentApp]!!["usageTime"] = currentUsageTime + usageTime
                            } catch (e: Exception) {
                                Log.e(TAG, "Error updating usage for $currentApp: ${e.message}")
                            }
                        }
                        
                        currentApp = ""
                    }
                }
            }
            
            // Convert milliseconds to minutes
            val totalMinutes = (totalScreenTime / 60000).toInt()
            result["totalUsageTime"] = totalMinutes
            
            // Sort apps by usage time (descending)
            appUsageMap.values.sortedByDescending { it["usageTime"] as Long }.forEach { appInfo ->
                val appUsageMinutes = ((appInfo["usageTime"] as Long) / 60000).toInt()
                if (appUsageMinutes > 0) {
                    val appData = HashMap<String, Any>()
                    appData["packageName"] = appInfo["packageName"] as String
                    appData["appName"] = appInfo["appName"] as Any
                    appData["usageTime"] = appUsageMinutes
                    appUsage.add(appData)
                }
            }
            
            result["appUsage"] = appUsage
            
            Log.d(TAG, "Final result: Total time: $totalMinutes minutes, Apps: ${appUsage.size}")
        } catch (e: Exception) {
            Log.e(TAG, "Error getting screen time data: ${e.message}", e)
            result["totalUsageTime"] = 0
            result["appUsage"] = appUsage
            result["error"] = "Error: ${e.message}"
        }
        
        return result
    }
    
    private fun openUsageStatsSettings() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            startActivity(intent)
            Log.d(TAG, "Usage stats settings opened successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening usage stats settings: ${e.message}", e)
        }
    }
}