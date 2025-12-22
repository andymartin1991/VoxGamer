package com.andymarcial.voxgamer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterActivity() {
    private val SCREEN_CHANNEL = "com.andymarcial.voxgamer/screen_state"
    private var screenReceiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerScreenReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterScreenReceiver()
                    eventSink = null
                }
            }
        )
    }

    private fun registerScreenReceiver() {
        if (screenReceiver == null) {
            screenReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (Intent.ACTION_SCREEN_OFF == intent.action) {
                        eventSink?.success("OFF")
                    } else if (Intent.ACTION_SCREEN_ON == intent.action) {
                        eventSink?.success("ON")
                    }
                }
            }
            val filter = IntentFilter()
            filter.addAction(Intent.ACTION_SCREEN_OFF)
            filter.addAction(Intent.ACTION_SCREEN_ON)
            try {
                registerReceiver(screenReceiver, filter)
            } catch (e: Exception) {
                // Ya registrado
            }
        }
    }

    private fun unregisterScreenReceiver() {
        if (screenReceiver != null) {
            try {
                unregisterReceiver(screenReceiver)
            } catch (e: Exception) {
                // Ya desregistrado o no registrado
            }
            screenReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterScreenReceiver()
        super.onDestroy()
    }
}
