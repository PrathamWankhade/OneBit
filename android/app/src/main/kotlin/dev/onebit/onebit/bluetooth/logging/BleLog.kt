package dev.onebit.onebit.bluetooth.logging

/**
 * Tag-scoped logger for the Bluetooth transport.
 *
 * Injectable so JVM unit tests can substitute a recording sink without
 * touching the Android framework (plain JUnit runs against a mockable
 * android.jar where [android.util.Log] throws).
 */
object BleLog {

    /** Where formatted lines go. Defaults to logcat once the transport starts. */
    @Volatile
    var sink: LogSink = LogcatSink()

    const val TAG = "OneBit/BLE"

    fun v(message: String, tag: String = TAG) = sink.v(tag, message)
    fun d(message: String, tag: String = TAG) = sink.d(tag, message)
    fun i(message: String, tag: String = TAG) = sink.i(tag, message)
    fun w(message: String, tag: String = TAG) = sink.w(tag, message)
    fun e(message: String, tag: String = TAG, throwable: Throwable? = null) =
        sink.e(tag, message, throwable)

    interface LogSink {
        fun v(tag: String, message: String)
        fun d(tag: String, message: String)
        fun i(tag: String, message: String)
        fun w(tag: String, message: String)
        fun e(tag: String, message: String, throwable: Throwable?)
    }
}
