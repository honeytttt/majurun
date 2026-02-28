package com.majurun.app

import android.content.Context
import androidx.annotation.NonNull
import com.google.android.gms.wearable.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class WearOSPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler, DataClient.OnDataChangedListener,
    MessageClient.OnMessageReceivedListener, CapabilityClient.OnCapabilityChangedListener {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private var eventSink: EventChannel.EventSink? = null

    private lateinit var dataClient: DataClient
    private lateinit var messageClient: MessageClient
    private lateinit var capabilityClient: CapabilityClient

    companion object {
        private const val CHANNEL = "com.majurun.app/watch"
        private const val EVENT_CHANNEL = "com.majurun.app/watch_events"
        private const val WEAR_CAPABILITY = "majurun_wear"
        private const val RUN_DATA_PATH = "/run_data"
        private const val WORKOUT_PATH = "/workout"
    }

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)

        // Initialize Wearable clients
        dataClient = Wearable.getDataClient(context)
        messageClient = Wearable.getMessageClient(context)
        capabilityClient = Wearable.getCapabilityClient(context)

        // Add listeners
        dataClient.addListener(this)
        messageClient.addListener(this)
        capabilityClient.addListener(this, WEAR_CAPABILITY)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)

        dataClient.removeListener(this)
        messageClient.removeListener(this)
        capabilityClient.removeListener(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "checkWatchStatus" -> checkWatchStatus(result)
            "startRun" -> startRun(result)
            "stopRun" -> stopRun(result)
            "syncRunData" -> syncRunData(call.arguments as? Map<String, Any>, result)
            "syncWorkout" -> syncWorkout(call.arguments as? Map<String, Any>, result)
            "getHeartRate" -> getHeartRate(result)
            "requestPermissions" -> requestPermissions(result)
            "openWatchApp" -> openWatchApp(result)
            else -> result.notImplemented()
        }
    }

    private fun checkWatchStatus(result: MethodChannel.Result) {
        capabilityClient.getCapability(WEAR_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { capabilityInfo ->
                val connected = capabilityInfo.nodes.isNotEmpty()
                result.success(mapOf(
                    "connected" to connected,
                    "appInstalled" to connected,
                    "platform" to "wearos"
                ))
            }
            .addOnFailureListener {
                result.success(mapOf(
                    "connected" to false,
                    "appInstalled" to false,
                    "platform" to "wearos"
                ))
            }
    }

    private fun startRun(result: MethodChannel.Result) {
        sendMessageToWatch("startRun", ByteArray(0)) { success ->
            result.success(success)
        }
    }

    private fun stopRun(result: MethodChannel.Result) {
        sendMessageToWatch("stopRun", ByteArray(0)) { success ->
            result.success(success)
        }
    }

    private fun syncRunData(data: Map<String, Any>?, result: MethodChannel.Result) {
        if (data == null) {
            result.success(null)
            return
        }

        val putDataRequest = PutDataMapRequest.create(RUN_DATA_PATH).apply {
            dataMap.putDouble("distance", (data["distance"] as? Number)?.toDouble() ?: 0.0)
            dataMap.putInt("duration", (data["duration"] as? Number)?.toInt() ?: 0)
            dataMap.putDouble("pace", (data["pace"] as? Number)?.toDouble() ?: 0.0)
            dataMap.putInt("heartRate", (data["heartRate"] as? Number)?.toInt() ?: 0)
            dataMap.putInt("calories", (data["calories"] as? Number)?.toInt() ?: 0)
            dataMap.putBoolean("isRunning", data["isRunning"] as? Boolean ?: false)
            dataMap.putBoolean("isPaused", data["isPaused"] as? Boolean ?: false)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        dataClient.putDataItem(putDataRequest)
            .addOnSuccessListener { result.success(null) }
            .addOnFailureListener { result.success(null) }
    }

    private fun syncWorkout(data: Map<String, Any>?, result: MethodChannel.Result) {
        if (data == null) {
            result.success(false)
            return
        }

        val putDataRequest = PutDataMapRequest.create(WORKOUT_PATH).apply {
            dataMap.putString("id", data["id"] as? String ?: "")
            dataMap.putString("name", data["name"] as? String ?: "")
            dataMap.putString("type", data["type"] as? String ?: "")
            dataMap.putDouble("targetDistance", (data["targetDistance"] as? Number)?.toDouble() ?: 0.0)
            dataMap.putInt("targetDuration", (data["targetDuration"] as? Number)?.toInt() ?: 0)
            dataMap.putLong("timestamp", System.currentTimeMillis())
        }.asPutDataRequest().setUrgent()

        dataClient.putDataItem(putDataRequest)
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { result.success(false) }
    }

    private fun getHeartRate(result: MethodChannel.Result) {
        sendMessageToWatch("getHeartRate", ByteArray(0)) { _ ->
            // Heart rate will be received via message
            result.success(null)
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        // Permissions handled on watch
        result.success(true)
    }

    private fun openWatchApp(result: MethodChannel.Result) {
        sendMessageToWatch("openApp", ByteArray(0)) { _ ->
            result.success(null)
        }
    }

    private fun sendMessageToWatch(path: String, data: ByteArray, callback: (Boolean) -> Unit) {
        capabilityClient.getCapability(WEAR_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
            .addOnSuccessListener { capabilityInfo ->
                val node = capabilityInfo.nodes.firstOrNull()
                if (node != null) {
                    messageClient.sendMessage(node.id, "/$path", data)
                        .addOnSuccessListener { callback(true) }
                        .addOnFailureListener { callback(false) }
                } else {
                    callback(false)
                }
            }
            .addOnFailureListener { callback(false) }
    }

    // DataClient listener
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED) {
                val dataItem = event.dataItem
                when (dataItem.uri.path) {
                    "/run_status" -> {
                        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                        val status = dataMap.getString("status")
                        when (status) {
                            "started" -> eventSink?.success(mapOf("type" to "run_started"))
                            "paused" -> eventSink?.success(mapOf("type" to "run_paused"))
                            "resumed" -> eventSink?.success(mapOf("type" to "run_resumed"))
                            "stopped" -> eventSink?.success(mapOf(
                                "type" to "run_stopped",
                                "distance" to dataMap.getDouble("distance"),
                                "duration" to dataMap.getInt("duration")
                            ))
                        }
                    }
                    "/heart_rate" -> {
                        val dataMap = DataMapItem.fromDataItem(dataItem).dataMap
                        eventSink?.success(mapOf(
                            "type" to "heart_rate_update",
                            "heartRate" to dataMap.getInt("heartRate")
                        ))
                    }
                }
            }
        }
    }

    // MessageClient listener
    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            "/run_started" -> eventSink?.success(mapOf("type" to "run_started"))
            "/run_paused" -> eventSink?.success(mapOf("type" to "run_paused"))
            "/run_resumed" -> eventSink?.success(mapOf("type" to "run_resumed"))
            "/run_stopped" -> {
                val data = String(messageEvent.data)
                // Parse data and send event
                eventSink?.success(mapOf("type" to "run_stopped"))
            }
        }
    }

    // CapabilityClient listener
    override fun onCapabilityChanged(capabilityInfo: CapabilityInfo) {
        val connected = capabilityInfo.nodes.isNotEmpty()
        eventSink?.success(mapOf(
            "type" to "connection_changed",
            "connected" to connected
        ))
    }

    // EventChannel StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
