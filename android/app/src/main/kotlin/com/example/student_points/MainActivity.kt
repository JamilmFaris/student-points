package com.example.student_points

import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val channelName = "student_points/contacts"
        private const val requestCodePickPhone = 9001
    }

    private var pickContactResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "pickPhoneNumber") {
                pickContactResult = result
                val intent = Intent(Intent.ACTION_PICK).apply {
                    type = ContactsContract.CommonDataKinds.Phone.CONTENT_TYPE
                }
                startActivityForResult(intent, requestCodePickPhone)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestCodePickPhone) return
        val res = pickContactResult
        pickContactResult = null
        if (res == null) return
        if (resultCode != Activity.RESULT_OK || data == null) {
            res.success(null)
            return
        }
        val uri = data.data ?: run {
            res.success(null)
            return
        }
        try {
            contentResolver.query(
                uri,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                    val number = if (idx >= 0) cursor.getString(idx)?.trim() else null
                    res.success(if (number.isNullOrEmpty()) null else number)
                } else {
                    res.success(null)
                }
            } ?: res.success(null)
        } catch (_: Exception) {
            res.success(null)
        }
    }
}
