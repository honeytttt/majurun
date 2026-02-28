package com.majurun.app

import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Background service to receive data and messages from Wear OS devices
 * even when the app is not in foreground
 */
class WearDataListenerService : WearableListenerService() {

    companion object {
        private const val TAG = "WearDataListenerService"
    }

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        super.onDataChanged(dataEvents)
        // Data changes are handled by WearOSPlugin when app is running
        // This service ensures messages are received when app is in background
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        // Messages are handled by WearOSPlugin when app is running
        // This service ensures messages are received when app is in background
    }
}
