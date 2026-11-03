package kr.co.spendingassistant.spending_assistant

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var csv: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "spending_assistant/files")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveCsv") {
                    result.notImplemented()
                } else if (pending != null) {
                    result.error("busy", "A save dialog is already open", null)
                } else {
                    val content = call.argument<String>("content")
                    val name = call.argument<String>("name")
                    if (content == null || name == null) {
                        result.error("invalid", "Missing file content", null)
                    } else {
                        pending = result
                        csv = content
                        try {
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "text/csv"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                            startActivityForResult(intent, 701)
                        } catch (error: Exception) {
                            pending = null
                            csv = null
                            result.error("save_failed", "Cannot open file picker", null)
                        }
                    }
                }
            }
    }

    @Deprecated("Android activity result API used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 701) return
        val result = pending ?: return
        pending = null
        val body = csv
        csv = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || body == null) {
            result.success(false)
            return
        }
        try {
            val stream = contentResolver.openOutputStream(data.data!!)
                ?: throw IllegalStateException("Cannot open destination")
            stream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            result.success(true)
        } catch (error: Exception) {
            result.error("save_failed", "Could not write the selected file", null)
        }
    }
}
