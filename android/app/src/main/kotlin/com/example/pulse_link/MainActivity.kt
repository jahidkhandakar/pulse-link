package com.example.pulse_link

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.telephony.PhoneStateListener
import android.telephony.SignalStrength
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.NetworkInterface
import java.util.UUID
import kotlin.math.abs
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {

    private val CHANNEL = "com.pulselink/native"

    private val REQ_WIFI_PERMS = 1001
    private val REQ_PHONE_PERMS = 1002

    // Step sensor
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    @Volatile private var latestStepCountSinceBoot: Int? = null

    // Accelerometer for activity detection
    private var accelSensor: Sensor? = null
    @Volatile private var latestActivityLabel: String? = null

    private var lastAccelTsMs: Long = 0L
    private var emaMotion: Double = 0.0

    private var lastStepSampleTsMs: Long = 0L
    private var lastStepSampleValue: Int? = null
    @Volatile private var recentStepDelta: Int = 0

    // Wi-Fi permissions callback
    private var pendingWifiPermResult: MethodChannel.Result? = null

    // Phone permissions callback
    private var pendingPhonePermResult: MethodChannel.Result? = null

    // Telephony
    private var telephonyManager: TelephonyManager? = null
    @Volatile private var latestCellularDbm: Int? = null

    private var telephonyCallback: TelephonyCallback? = null
    private var phoneStateListener: PhoneStateListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sensors
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        accelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        // Telephony
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

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

                    // Wi-Fi permission bridge
                    "hasWifiPermissions" -> result.success(hasWifiPermissions())
                    "requestWifiPermissions" -> requestWifiPermissions(result)

                    // Phone permission bridge
                    "hasPhonePermissions" -> result.success(hasPhonePermissions())
                    "requestPhonePermissions" -> requestPhonePermissions(result)

                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()

        // Step + accelerometer sensors
        stepSensor?.let { sensor ->
            sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
        accelSensor?.let { sensor ->
            sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
        }

        // Signal strength updates (best-effort)
        startSignalStrengthListener()
    }

    override fun onPause() {
        super.onPause()
        sensorManager?.unregisterListener(this)
        stopSignalStrengthListener()
    }

    // ---------- Sensors ----------

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> {
                val value = event.values.firstOrNull()?.toInt()
                if (value != null) {
                    latestStepCountSinceBoot = value
                    updateStepDelta(value)
                    updateActivityLabel()
                }
            }

            Sensor.TYPE_ACCELEROMETER -> {
                updateMotionEma(event.values)
                updateActivityLabel()
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // no-op
    }

    private fun updateStepDelta(currentSteps: Int) {
        val nowMs = System.currentTimeMillis()

        if (lastStepSampleTsMs == 0L) {
            lastStepSampleTsMs = nowMs
            lastStepSampleValue = currentSteps
            recentStepDelta = 0
            return
        }

        // sample window ~6 seconds
        if (nowMs - lastStepSampleTsMs >= 6000) {
            val prev = lastStepSampleValue ?: currentSteps
            recentStepDelta = (currentSteps - prev).coerceAtLeast(0)
            lastStepSampleValue = currentSteps
            lastStepSampleTsMs = nowMs
        }
    }

    private fun updateMotionEma(values: FloatArray) {
        val ax = values.getOrNull(0)?.toDouble() ?: return
        val ay = values.getOrNull(1)?.toDouble() ?: return
        val az = values.getOrNull(2)?.toDouble() ?: return

        val mag = sqrt(ax * ax + ay * ay + az * az)
        val motion = abs(mag - 9.81) // remove gravity approx

        val alpha = 0.10
        emaMotion = alpha * motion + (1 - alpha) * emaMotion

        lastAccelTsMs = System.currentTimeMillis()
    }

    private fun updateActivityLabel() {
        val nowMs = System.currentTimeMillis()
        val accelFresh = (nowMs - lastAccelTsMs) <= 5000

        val hasSteps = latestStepCountSinceBoot != null

        val walkingBySteps = hasSteps && recentStepDelta >= 3     // >= 3 steps in ~6s
        val walkingByMotion = accelFresh && emaMotion >= 1.2      // motion threshold
        val stillByMotion = accelFresh && emaMotion <= 0.35       // low motion

        latestActivityLabel = when {
            walkingBySteps || walkingByMotion -> "Walking"
            stillByMotion -> "Still"
            accelFresh || hasSteps -> "Still"
            else -> null
        }
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
        val tel = readTelephonyInfoOrNull()

        return mapOf(
            "deviceId" to deviceId,
            "deviceName" to deviceName,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE,

            "batteryLevel" to battery.level,
            "batteryTempC" to battery.tempC,
            "batteryHealth" to battery.healthLabel,

            "stepsSinceBoot" to latestStepCountSinceBoot,
            "activity" to latestActivityLabel,

            "wifiSsid" to wifi?.ssid,
            "wifiRssi" to wifi?.rssi,
            "localIp" to wifi?.localIp,

            "carrierName" to tel?.carrierName,
            "cellularDbm" to tel?.dbm,
            "simState" to tel?.simState,

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

        val rawSsid = info?.ssid
        val ssid = rawSsid
            ?.takeIf { it.isNotBlank() && it != "<unknown ssid>" }
            ?.removePrefix("\"")
            ?.removeSuffix("\"")

        val rssi = info?.rssi
        val ip = getLocalIpv4Address()

        return WifiInfo(ssid = ssid, rssi = rssi, localIp = ip)
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

    // ---------- Telephony ----------

    private data class TelephonyInfo(
        val carrierName: String?,
        val simState: String?,
        val dbm: Int?
    )

    private fun readTelephonyInfoOrNull(): TelephonyInfo? {
        val tm = telephonyManager ?: return null

        val carrier = try { tm.networkOperatorName } catch (_: Exception) { null }

        val simState = try {
            when (tm.simState) {
                TelephonyManager.SIM_STATE_READY -> "READY"
                TelephonyManager.SIM_STATE_ABSENT -> "ABSENT"
                TelephonyManager.SIM_STATE_PIN_REQUIRED -> "PIN_REQUIRED"
                TelephonyManager.SIM_STATE_PUK_REQUIRED -> "PUK_REQUIRED"
                TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "NETWORK_LOCKED"
                TelephonyManager.SIM_STATE_NOT_READY -> "NOT_READY"
                TelephonyManager.SIM_STATE_PERM_DISABLED -> "PERM_DISABLED"
                TelephonyManager.SIM_STATE_UNKNOWN -> "UNKNOWN"
                else -> "UNKNOWN"
            }
        } catch (_: Exception) { null }

        val dbm = if (hasPhonePermissions()) latestCellularDbm else null

        return TelephonyInfo(
            carrierName = carrier?.takeIf { it.isNotBlank() },
            simState = simState,
            dbm = dbm
        )
    }

    private fun startSignalStrengthListener() {
        val tm = telephonyManager ?: return
        if (!hasPhonePermissions()) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (telephonyCallback == null) {
                    telephonyCallback = object : TelephonyCallback(), TelephonyCallback.SignalStrengthsListener {
                        override fun onSignalStrengthsChanged(signalStrength: SignalStrength) {
                            latestCellularDbm = extractDbm(signalStrength)
                        }
                    }
                }
                tm.registerTelephonyCallback(mainExecutor, telephonyCallback as TelephonyCallback)
            } else {
                if (phoneStateListener == null) {
                    phoneStateListener = object : PhoneStateListener() {
                        override fun onSignalStrengthsChanged(signalStrength: SignalStrength?) {
                            if (signalStrength != null) {
                                latestCellularDbm = extractDbm(signalStrength)
                            }
                        }
                    }
                }
                @Suppress("DEPRECATION")
                tm.listen(phoneStateListener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
            }
        } catch (_: Exception) {
            // Some OEMs restrict this; keep null
        }
    }

    private fun stopSignalStrengthListener() {
        val tm = telephonyManager ?: return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                telephonyCallback?.let { tm.unregisterTelephonyCallback(it) }
            } else {
                @Suppress("DEPRECATION")
                tm.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
            }
        } catch (_: Exception) {}
    }

    private fun extractDbm(signalStrength: SignalStrength): Int? {
        return try {
            val cells = signalStrength.cellSignalStrengths
            if (cells.isNullOrEmpty()) return null
            val dbm = cells[0].dbm
            if (dbm == Int.MAX_VALUE) null else dbm
        } catch (_: Exception) {
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
        if (hasWifiPermissions()) { result.success(true); return }

        if (pendingWifiPermResult != null) {
            result.error("PERM_IN_PROGRESS", "Wi-Fi permission request already running", null)
            return
        }

        pendingWifiPermResult = result

        val perms = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33) perms.add(Manifest.permission.NEARBY_WIFI_DEVICES)

        ActivityCompat.requestPermissions(this, perms.toTypedArray(), REQ_WIFI_PERMS)
    }

    private fun hasPhonePermissions(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestPhonePermissions(result: MethodChannel.Result) {
        if (hasPhonePermissions()) { result.success(true); return }

        if (pendingPhonePermResult != null) {
            result.error("PERM_IN_PROGRESS", "Phone permission request already running", null)
            return
        }

        pendingPhonePermResult = result

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_PHONE_STATE),
            REQ_PHONE_PERMS
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            REQ_WIFI_PERMS -> {
                val ok = hasWifiPermissions()
                pendingWifiPermResult?.success(ok)
                pendingWifiPermResult = null
            }
            REQ_PHONE_PERMS -> {
                val ok = hasPhonePermissions()
                pendingPhonePermResult?.success(ok)
                pendingPhonePermResult = null
                if (ok) startSignalStrengthListener()
            }
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
