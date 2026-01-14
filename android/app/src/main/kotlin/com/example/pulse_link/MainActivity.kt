package com.example.pulse_link

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.UUID

class MainActivity : FlutterActivity(), SensorEventListener {

    private val CHANNEL = "com.pulselink/native"
    private val REQ_WIFI_PERMS = 1001

    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null

    @Volatile
    private var latestStepCountSinceBoot: Int? = null

    // Permission request callback holder
    private var pendingPermResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

                    "requestWifiPermissions" -> {
                        requestWifiPermissions(result)
                    }

                    "hasWifiPermissions" -> {
                        result.success(hasWifiPermissions())
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
            if (value != null) latestStepCountSinceBoot = value.toInt()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    // ---------- Snapshot ----------

    @SuppressLint("HardwareIds")
    private fun getSnapshot(): Map<String, Any?> {
        val ctx = applicationContext
        val battery = readBattery(ctx)
        val deviceId = getOrCreateDeviceId(ctx)

        val deviceName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME) ?: "Android"
        } else "Android"

        val wifi = readWifiInfoOrNull(ctx)

        return mapOf(
            "deviceId" to deviceId,
            "deviceName" to deviceName,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,

            "batteryLevel" to battery.level,
            "batteryTempC" to battery.tempC,
            "batteryHealth" to battery.healthLabel,

            "stepsSinceBoot" to latestStepCountSinceBoot,

            // Wi-Fi values (null if not permitted / unavailable)
            "wifiSsid" to wifi?.ssid,
            "wifiRssi" to wifi?.rssi,
            "localIp" to wifi?.localIp,

            // Next features
            "activity" to null,
            "carrierName" to null,
            "cellularDbm" to null,
            "simState" to null,

            "timestamp" to java.time.Instant.now().toString()
        )
    }

    // ---------- Battery ----------

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

        return BatteryInfo(levelPct, tempC, healthLabel)
    }

    // ---------- Wi-Fi ----------

    private data class WifiInfo(
        val ssid: String?,
        val rssi: Int?,
        val localIp: String?
    )

    private fun readWifiInfoOrNull(ctx: Context): WifiInfo? {
        if (!hasWifiPermissions()) return null

        val wifiManager = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val info = wifiManager.connectionInfo

        // SSID may be quoted, or "<unknown ssid>" if not available
        val rawSsid = info?.ssid
        val ssid = rawSsid
            ?.takeIf { it.isNotBlank() && it != "<unknown ssid>" }
            ?.removePrefix("\"")
            ?.removeSuffix("\"")

        val rssi = info?.rssi

        // IP from WifiManager can be 0 sometimes; we’ll compute robustly via interfaces
        val ip = getLocalIpv4Address()

        return WifiInfo(
            ssid = ssid,
            rssi = rssi,
            localIp = ip
        )
    }

    private fun getLocalIpv4Address(): String? {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            for (intf in interfaces) {
                val addrs = intf.inetAddresses
                for (addr in addrs) {
                    if (!addr.isLoopbackAddress && addr is Inet4Address) {
                        val ip = addr.hostAddress
                        if (!ip.isNullOrBlank()) return ip
                    }
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    // ---------- Permissions ----------

    private fun hasWifiPermissions(): Boolean {
        val hasFineLocation = ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED

        val hasNearbyWifi = if (Build.VERSION.SDK_INT >= 33) {
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
        } else true

        return hasFineLocation && hasNearbyWifi
    }

    private fun requestWifiPermissions(result: MethodChannel.Result) {
        if (hasWifiPermissions()) {
            result.success(true)
            return
        }

        if (pendingPermResult != null) {
            result.error("PERM_IN_PROGRESS", "Permission request already running", null)
            return
        }

        pendingPermResult = result

        val perms = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33) {
            perms.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        }

        ActivityCompat.requestPermissions(this, perms.toTypedArray(), REQ_WIFI_PERMS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQ_WIFI_PERMS) {
            val ok = hasWifiPermissions()
            pendingPermResult?.success(ok)
            pendingPermResult = null
        }
    }

    // ---------- Device ID ----------

    private fun getOrCreateDeviceId(ctx: Context): String {
        val prefs = ctx.getSharedPreferences("pulselink_prefs", Context.MODE_PRIVATE)
        val existing = prefs.getString("device_id", null)
        if (existing != null) return existing

        val newId = UUID.randomUUID().toString()
        prefs.edit().putString("device_id", newId).apply()
        return newId
    }
}
