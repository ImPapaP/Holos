package ph.edu.bulsu.gabay

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Gabay: reads the ambient light sensor once (lux) for the Auto theme.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gabay/light").setMethodCallHandler { call, result ->
            if (call.method != "read") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            val sensor = sm.getDefaultSensor(Sensor.TYPE_LIGHT)
            if (sensor == null) {
                result.success(-1.0)
                return@setMethodCallHandler
            }
            var done = false
            val listener = object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    if (done) return
                    done = true
                    sm.unregisterListener(this)
                    result.success(event.values[0].toDouble())
                }
                override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
            }
            sm.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
            Handler(Looper.getMainLooper()).postDelayed({
                if (!done) {
                    done = true
                    sm.unregisterListener(listener)
                    result.success(-1.0)
                }
            }, 1500)
        }
    }
}
