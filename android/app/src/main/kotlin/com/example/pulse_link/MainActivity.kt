package com.example.pulse_link

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
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
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.net.Inet4Address
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread
import kotlin.math.abs
import kotlin.math.sqrt

class MainActivity : FlutterActivity(), SensorEventListener {

    // -------- Channels --------
    private val METHOD_CH = "com.pulselink/native"
    private val RECEIVED_EVENTS_CH = "com.pulselink/events/received"
    private val PEERS_EVENTS_CH = "com.pulselink/events/peers"

    // -------- Permission request codes --------
    private val REQ_WIFI_PERMS = 1001
    private val REQ_PHONE_PERMS = 1002
    private val REQ_ACTIVITY_PERMS = 1003

    // -------- Sensors --------
    private var sensorManager: SensorManager? = null
    private var stepSensor: Sensor? = null
    @Volatile private var latestStepCountSinceBoot: Int? = null

    private var accelSensor: Sensor? = null
    @Volatile private var latestActivityLabel: String? = null
    private var lastAccelTsMs: Long = 0L
    private var emaMotion: Double = 0.0
    private var lastStepSampleTsMs: Long = 0L
    private var lastStepSampleValue: Int? = null
    @Volatile private var recentStepDelta: Int = 0

    // -------- Permissions result holders --------
    private var pendingWifiPermResult: MethodChannel.Result? = null
    private var pendingPhonePermResult: MethodChannel.Result? = null
    private var pendingActivityPermResult: MethodChannel.Result? = null

    // -------- Telephony --------
    private var telephonyManager: TelephonyManager? = null
    @Volatile private var latestCellularDbm: Int? = null
    private var telephonyCallback: TelephonyCallback? = null
    private var phoneStateListener: PhoneStateListener? = null

    // -------- Device ID --------
    private var cachedDeviceId: String? = null

    // -------- Networking (NSD + TCP) --------
    private var nsdManager: NsdManager? = null
    private var serverSocket: ServerSocket? = null
    @Volatile private var serverPort: Int? = null
    @Volatile private var isServerRunning: Boolean = false
    @Volatile private var isNetworkingStarted: Boolean = false

    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null
    private var registeredServiceName: String? = null

    private val SERVICE_TYPE = "_pulselink._tcp."

    // peers: key = serviceName
    private val peers = ConcurrentHashMap<String, Peer>()

    data class Peer(
        val serviceName: String,
        val host: String,
        val port: Int,
        val deviceName: String? = null,
        val model: String? = null
    )

    // -------- Event sinks --------
    private var receivedSink: EventChannel.EventSink? = null
    private var peersSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Sensors
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        accelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        // Telephony
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager

        // NSD
        nsdManager = getSystemService(Context.NSD_SERVICE) as NsdManager

        // Event channels
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RECEIVED_EVENTS_CH)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    receivedSink = events
                }
                override fun onCancel(arguments: Any?) {
                    receivedSink = null
                }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PEERS_EVENTS_CH)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    peersSink = events
                    pushPeersUpdate()
                }
                override fun onCancel(arguments: Any?) {
                    peersSink = null
                }
            })

        // Method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CH)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSnapshot" -> {
                        try { result.success(getSnapshot()) }
                        catch (e: Exception) { result.error("SNAPSHOT_ERROR", e.message, null) }
                    }

                    "hasWifiPermissions" -> result.success(hasWifiPermissions())
                    "requestWifiPermissions" -> requestWifiPermissions(result)

                    "hasPhonePermissions" -> result.success(hasPhonePermissions())
                    "requestPhonePermissions" -> requestPhonePermissions(result)

                    "hasActivityPermissions" -> result.success(hasActivityPermissions())
                    "requestActivityPermissions" -> requestActivityPermissions(result)

                    "startNetworking" -> {
                        startNetworking()
                        result.success(true)
                    }
                    "stopNetworking" -> {
                        stopNetworking()
                        result.success(true)
                    }
                    "getPeers" -> {
                        result.success(getPeersAsList())
                    }
                    "sendSnapshotToPeer" -> {
                        val serviceName = call.argument<String>("serviceName")
                        val payload = call.argument<String>("payloadJson")
                        if (serviceName.isNullOrBlank() || payload.isNullOrBlank()) {
                            result.error("BAD_ARGS", "serviceName/payloadJson required", null)
                        } else {
                            // run network I/O off main thread
                            thread(name = "pulselink-send") {
                                val ok = sendToPeer(serviceName, payload)
                                runOnUiThread { result.success(ok) }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()

        // Step counter: Android 10+ often needs ACTIVITY_RECOGNITION permission
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q || hasActivityPermissions()) {
            stepSensor?.let { sensor ->
                sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            }
        }

        accelSensor?.let { sensor ->
            sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
        }

        startSignalStrengthListener()
    }

    override fun onPause() {
        super.onPause()
        sensorManager?.unregisterListener(this)
        stopSignalStrengthListener()
    }

    // ---------------- Sensors ----------------

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

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun updateStepDelta(currentSteps: Int) {
        val nowMs = System.currentTimeMillis()
        if (lastStepSampleTsMs == 0L) {
            lastStepSampleTsMs = nowMs
            lastStepSampleValue = currentSteps
            recentStepDelta = 0
            return
        }
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
        val motion = abs(mag - 9.81)

        val alpha = 0.10
        emaMotion = alpha * motion + (1 - alpha) * emaMotion

        lastAccelTsMs = System.currentTimeMillis()
    }

    private fun updateActivityLabel() {
        val nowMs = System.currentTimeMillis()
        val accelFresh = (nowMs - lastAccelTsMs) <= 5000

        val hasSteps = latestStepCountSinceBoot != null
        val walkingBySteps = hasSteps && recentStepDelta >= 3
        val walkingByMotion = accelFresh && emaMotion >= 1.2
        val stillByMotion = accelFresh && emaMotion <= 0.35

        latestActivityLabel = when {
            walkingBySteps || walkingByMotion -> "Walking"
            stillByMotion -> "Still"
            accelFresh || hasSteps -> "Still"
            else -> null
        }
    }

    // ---------------- Snapshot ----------------

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
            "stepSensorAvailable" to (stepSensor != null),

            "activity" to latestActivityLabel,
            "activityPermOk" to hasActivityPermissions(),

            "wifiSsid" to wifi?.ssid,
            "wifiRssi" to wifi?.rssi,
            "localIp" to wifi?.localIp,

            "carrierName" to tel?.carrierName,
            "cellularDbm" to tel?.dbm,
            "simState" to tel?.simState,

            "timestamp" to java.time.Instant.now().toString()
        )
    }

    // ---------------- Battery ----------------

    private data class BatteryInfo(val level: Int, val tempC: Double, val healthLabel: String)

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

        val label = when (health) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheat"
            else -> "Unknown"
        }
        return BatteryInfo(levelPct, tempC, label)
    }

    // ---------------- Wi-Fi ----------------

    private data class WifiInfo(val ssid: String?, val rssi: Int?, val localIp: String?)

    private fun readWifiInfoOrNull(ctx: Context): WifiInfo? {
        if (!hasWifiPermissions()) return null

        val wifiManager = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        val info = wifiManager.connectionInfo

        val rawSsid = info?.ssid
        val ssid = rawSsid
            ?.takeIf { it.isNotBlank() && it != "<unknown ssid>" }
            ?.removePrefix("\"")?.removeSuffix("\"")

        val rssi = info?.rssi
        val ip = getLocalWifiIp(ctx)

        return WifiInfo(ssid, rssi, ip)
    }

    private fun getLocalWifiIp(ctx: Context): String? {
        return try {
            val wifiManager = ctx.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val dhcp = wifiManager.dhcpInfo ?: return null
            val ipInt = dhcp.ipAddress
            if (ipInt == 0) return null

            String.format(
                "%d.%d.%d.%d",
                ipInt and 0xff,
                ipInt shr 8 and 0xff,
                ipInt shr 16 and 0xff,
                ipInt shr 24 and 0xff
            )
        } catch (_: Exception) {
            null
        }
    }

    // ---------------- Telephony ----------------

    private data class TelephonyInfo(val carrierName: String?, val simState: String?, val dbm: Int?)

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
                telephonyCallback = object : TelephonyCallback(),
                    TelephonyCallback.SignalStrengthsListener {
                    override fun onSignalStrengthsChanged(signalStrength: SignalStrength) {
                        try {
                            latestCellularDbm = extractDbm(signalStrength)
                        } catch (_: Exception) {
                            // ignore
                        }
                    }
                }
            }
            tm.registerTelephonyCallback(mainExecutor, telephonyCallback as TelephonyCallback)
        } else {
            if (phoneStateListener == null) {
                phoneStateListener = object : PhoneStateListener() {
                    override fun onSignalStrengthsChanged(signalStrength: SignalStrength?) {
                        try {
                            if (signalStrength != null) {
                                latestCellularDbm = extractDbm(signalStrength)
                            }
                        } catch (_: Exception) {
                            // swallow OEM / API crashes safely
                        }
                    }
                }
            }

            @Suppress("DEPRECATION")
            tm.listen(phoneStateListener, PhoneStateListener.LISTEN_SIGNAL_STRENGTHS)
        }
    } catch (_: Exception) {
        // ignore
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
        // ✅ API 29+ (Android 10+) has cellSignalStrengths
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val cells = signalStrength.cellSignalStrengths
            if (cells.isNullOrEmpty()) null else cells[0].dbm
        } else {
            // ✅ API 28 and below (Android 9 and older)
            @Suppress("DEPRECATION")
            val asu = signalStrength.gsmSignalStrength
            if (asu == 99 || asu <= 0) null else (-113 + 2 * asu)
        }
    } catch (_: Exception) {
            null
        }
    }


    // ---------------- Permissions ----------------

    private fun hasWifiPermissions(): Boolean {
        val fine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED

        val nearby = if (Build.VERSION.SDK_INT >= 33) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.NEARBY_WIFI_DEVICES) ==
                    PackageManager.PERMISSION_GRANTED
        } else true

        return fine && nearby
    }

    private fun requestWifiPermissions(result: MethodChannel.Result) {
        if (hasWifiPermissions()) { result.success(true); return }
        if (pendingWifiPermResult != null) {
            result.error("PERM_IN_PROGRESS", "Wi-Fi permission request already running", null); return
        }
        pendingWifiPermResult = result
        val perms = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33) perms.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        ActivityCompat.requestPermissions(this, perms.toTypedArray(), REQ_WIFI_PERMS)
    }

    private fun hasPhonePermissions(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) ==
                PackageManager.PERMISSION_GRANTED
    }

    private fun requestPhonePermissions(result: MethodChannel.Result) {
        if (hasPhonePermissions()) { result.success(true); return }
        if (pendingPhonePermResult != null) {
            result.error("PERM_IN_PROGRESS", "Phone permission request already running", null); return
        }
        pendingPhonePermResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.READ_PHONE_STATE),
            REQ_PHONE_PERMS
        )
    }

    private fun hasActivityPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACTIVITY_RECOGNITION) ==
                    PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun requestActivityPermissions(result: MethodChannel.Result) {
        if (hasActivityPermissions()) { result.success(true); return }
        if (pendingActivityPermResult != null) {
            result.error("PERM_IN_PROGRESS", "Activity permission request already running", null); return
        }
        pendingActivityPermResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            REQ_ACTIVITY_PERMS
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
            REQ_ACTIVITY_PERMS -> {
                val ok = hasActivityPermissions()
                pendingActivityPermResult?.success(ok)
                pendingActivityPermResult = null

                // If granted, register step sensor now
                if (ok) {
                    stepSensor?.let { sensor ->
                        sensorManager?.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
                    }
                }
            }
        }
    }

    // ---------------- Device ID ----------------

    private fun getOrCreateDeviceId(ctx: Context): String {
        cachedDeviceId?.let { return it }
        val prefs = ctx.getSharedPreferences("pulselink_prefs", Context.MODE_PRIVATE)
        val existing = prefs.getString("device_id", null)
        if (existing != null) {
            cachedDeviceId = existing
            return existing
        }
        val newId = UUID.randomUUID().toString()
        prefs.edit().putString("device_id", newId).apply()
        cachedDeviceId = newId
        return newId
    }

    private fun getDeviceNameForNsd(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME) ?: "Android"
        } else "Android"
    }

    // ============================================================
    // =================== NETWORKING (NSD + TCP) =================
    // ============================================================

    private fun startNetworking() {
        if (isNetworkingStarted) return
        isNetworkingStarted = true

        startTcpServer()

        thread(name = "pulselink-net-boot") {
            var tries = 0
            while (serverPort == null && tries < 50) {
                Thread.sleep(20)
                tries++
            }

            runOnUiThread {
                try { unregisterService() } catch (_: Exception) {}
                registerService()
                discoverServices()
            }
        }
    }

    private fun stopNetworking() {
        isNetworkingStarted = false
        try { stopDiscovery() } catch (_: Exception) {}
        try { unregisterService() } catch (_: Exception) {}
        try { stopTcpServer() } catch (_: Exception) {}
        peers.clear()
        pushPeersUpdate()
    }

    private fun startTcpServer() {
        if (isServerRunning) return

        isServerRunning = true
        thread(name = "pulselink-server") {
            try {
                val ss = ServerSocket(0)
                serverSocket = ss
                serverPort = ss.localPort

                while (isServerRunning) {
                    val client = ss.accept()
                    thread(name = "pulselink-client") { handleClient(client) }
                }
            } catch (_: Exception) {
            } finally {
                isServerRunning = false
            }
        }
    }

    private fun stopTcpServer() {
        isServerRunning = false
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        serverPort = null
    }

    private fun handleClient(socket: Socket) {
        try {
            socket.soTimeout = 5000
            val input = socket.getInputStream()
            val buffer = ByteArray(4096)
            val baos = ByteArrayOutputStream()

            while (true) {
                val read = input.read(buffer)
                if (read == -1) break
                baos.write(buffer, 0, read)
            }

            val payload = baos.toString(Charsets.UTF_8.name()).trim()
            if (payload.isNotEmpty()) {
                runOnUiThread { receivedSink?.success(payload) }
            }
        } catch (_: Exception) {
        } finally {
            try { socket.close() } catch (_: Exception) {}
        }
    }

    private fun registerService() {
        val port = serverPort ?: return
        val id = getOrCreateDeviceId(applicationContext)

        val serviceName = "PulseLink-$id"
        registeredServiceName = serviceName

        val dn = getDeviceNameForNsd()
        val model = Build.MODEL

        val serviceInfo = NsdServiceInfo().apply {
            this.serviceName = serviceName
            this.serviceType = SERVICE_TYPE
            this.port = port

            // ✅ Step 7: TXT records
            setAttribute("dn", dn)
            setAttribute("model", model)
        }

        registrationListener = object : NsdManager.RegistrationListener {
            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo?, errorCode: Int) {}
            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo?, errorCode: Int) {}
            override fun onServiceRegistered(serviceInfo: NsdServiceInfo?) {
                serviceInfo?.serviceName?.let { registeredServiceName = it }
            }
            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo?) {}
        }

        try {
            nsdManager?.registerService(serviceInfo, NsdManager.PROTOCOL_DNS_SD, registrationListener)
        } catch (_: Exception) {}
    }

    private fun unregisterService() {
        try {
            registrationListener?.let { nsdManager?.unregisterService(it) }
        } catch (_: Exception) {}
        registrationListener = null
    }

    private fun discoverServices() {
        if (discoveryListener != null) return

        discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(regType: String) {}
            override fun onDiscoveryStopped(serviceType: String) {}

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) { stopDiscovery() }
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) { stopDiscovery() }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (serviceInfo.serviceType != SERVICE_TYPE) return

                val myName = registeredServiceName ?: "PulseLink-${getOrCreateDeviceId(applicationContext)}"
                if (serviceInfo.serviceName == myName) return

                resolveService(serviceInfo)
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                peers.remove(serviceInfo.serviceName)
                pushPeersUpdate()
            }
        }

        try {
            nsdManager?.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
        } catch (_: Exception) {}
    }

    private fun stopDiscovery() {
        try {
            discoveryListener?.let { nsdManager?.stopServiceDiscovery(it) }
        } catch (_: Exception) {}
        discoveryListener = null
    }

    private fun resolveService(serviceInfo: NsdServiceInfo) {
        val resolveListener = object : NsdManager.ResolveListener {
            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {}

            override fun onServiceResolved(resolved: NsdServiceInfo) {
                val host = resolved.host ?: return
                val port = resolved.port
                val name = resolved.serviceName

                // Prefer IPv4 only
                val ip = (host as? Inet4Address)?.hostAddress ?: return

                // ✅ Step 7: read TXT attrs
                val attrs = resolved.attributes
                val dn = attrs["dn"]?.toString(Charsets.UTF_8)
                val model = attrs["model"]?.toString(Charsets.UTF_8)

                val myIp = getLocalWifiIp(applicationContext)
                val myPort = serverPort
                if (myIp != null && myPort != null && ip == myIp && port == myPort) return

                peers[name] = Peer(name, ip, port, dn, model)
                pushPeersUpdate()
            }
        }

        try { nsdManager?.resolveService(serviceInfo, resolveListener) }
        catch (_: Exception) {}
    }

    private fun pushPeersUpdate() {
        val list = getPeersAsList()
        runOnUiThread { peersSink?.success(list) }
    }

    private fun getPeersAsList(): List<Map<String, Any?>> {
        return peers.values.map {
            mapOf(
                "serviceName" to it.serviceName,
                "host" to it.host,
                "port" to it.port,
                "deviceName" to it.deviceName,
                "model" to it.model
            )
        }.sortedBy { it["serviceName"].toString() }
    }

    private fun sendToPeer(serviceName: String, payloadJson: String): Boolean {
        val peer = peers[serviceName] ?: return false

        return try {
            Socket().use { socket ->
                socket.connect(InetSocketAddress(peer.host, peer.port), 2000)
                socket.soTimeout = 5000
                socket.getOutputStream().use { os ->
                    os.write(payloadJson.toByteArray(Charsets.UTF_8))
                    os.flush()
                }
            }
            true
        } catch (_: Exception) {
            false
        }
    }
}
