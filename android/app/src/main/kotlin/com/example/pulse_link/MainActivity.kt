package com.example.pulse_link

import android.annotation.SuppressLint
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity(), SensorEventListener {

    private val CHANNEL = "com.pulselink/native"

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null

    @Volatile
    private var latestStepCountSinceBoot: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Step counter sensor setup
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSnapshot" -> {
                        try {
                            result.success(getSnapshot())
                        } catch (e: Exception) {
                            result.error("SNAPSHOT_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        stepSensor?.let { sensor ->
            sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    override fun onPause() {
        super.onPause()
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_STEP_COUNTER) {
            val value = event.values.firstOrNull()
            if (value != null) {
                // Steps since last boot
                latestStepCountSinceBoot = value.toInt()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    @SuppressLint("HardwareIds")
    private fun getSnapshot(): Map<String, Any?> {
        val ctx = applicationContext

        val battery = readBattery(ctx)
        val deviceId = getOrCreateDeviceId(ctx)

        val deviceName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME) ?: "Android"
        } else {
            "Android"
        }

        return mapOf(
            "deviceId" to deviceId,
            "deviceName" to deviceName,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,

            "batteryLevel" to battery.level,
            "batteryTempC" to battery.tempC,
            "batteryHealth" to battery.healthLabel,

            // ✅ Real step count since boot (null if sensor unavailable)
            "stepsSinceBoot" to latestStepCountSinceBoot,

            // Next features will fill these (keep null for now = not mocked)
            "activity" to null,
            "wifiSsid" to null,
            "wifiRssi" to null,
            "localIp" to null,
            "carrierName" to null,
            "cellularDbm" to null,
            "simState" to null,

            "timestamp" to java.time.Instant.now().toString()
        )
    }

    private data class BatteryInfo(
        val level: Int,
        val tempC: Double,
        val healthLabel: String
    )

    private fun readBattery(ctx: Context): BatteryInfo {
        val bm = ctx.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val levelFallback = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        return getBatteryFromIntent(ctx, levelFallback)
    }

    private fun getBatteryFromIntent(ctx: Context, levelFallback: Int): BatteryInfo {
        val intent = ctx.registerReceiver(
            null,
            android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED)
        )

        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, levelFallback) ?: levelFallback
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val levelPct = ((level.toDouble() / scale.toDouble()) * 100.0).toInt()

        val tempTenths = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0
        val tempC = tempTenths / 10.0

        val health = intent?.getIntExtra(
            BatteryManager.EXTRA_HEALTH,
            BatteryManager.BATTERY_HEALTH_UNKNOWN
        ) ?: BatteryManager.BATTERY_HEALTH_UNKNOWN

        val healthLabel = when (health) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
            else -> "Unknown"
        }

        return BatteryInfo(
            level = levelPct,
            tempC = tempC,
            healthLabel = healthLabel
        )
    }

    private fun getOrCreateDeviceId(ctx: Context): String {
        val prefs = ctx.getSharedPreferences("pulselink_prefs", Context.MODE_PRIVATE)
        val existing = prefs.getString("device_id", null)
        if (existing != null) return existing

        val newId = UUID.randomUUID().toString()
        prefs.edit().putString("device_id", newId).apply()
        return newId
    }
}
