package dev.onebit.onebit.bluetooth.logging

import android.util.Log

/** Sends formatted lines to logcat. */
class LogcatSink : BleLog.LogSink {
    private fun prefix(tag: String) = tag

    override fun v(tag: String, message: String) {
        Log.v(prefix(tag), message)
    }

    override fun d(tag: String, message: String) {
        Log.d(prefix(tag), message)
    }

    override fun i(tag: String, message: String) {
        Log.i(prefix(tag), message)
    }

    override fun w(tag: String, message: String) {
        Log.w(prefix(tag), message)
    }

    override fun e(tag: String, message: String, throwable: Throwable?) {
        if (throwable == null) {
            Log.e(prefix(tag), message)
        } else {
            Log.e(prefix(tag), message, throwable)
        }
    }
}