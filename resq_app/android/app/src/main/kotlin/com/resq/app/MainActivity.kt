package com.resq.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.provider.ContactsContract
import android.telephony.SmsManager
import android.util.Base64
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.resq.app.ble.BleMeshManager
import com.resq.app.wifidirect.WifiDirectManager
class MainActivity: FlutterActivity() {
    private val BLE_CHANNEL = "com.resq.app/ble_mesh"
    private val WIFI_CHANNEL = "com.resq.app/wifi_direct"
    private val CONTACTS_CHANNEL = "com.resq.app/emergency_contacts"
    private val VOICE_CHANNEL = "com.resq.app/voice_recorder"
    private val BLE_PERMISSION_REQUEST = 1001
    private val WIFI_PERMISSION_REQUEST = 2001
    private val CONTACTS_PERMISSION_REQUEST = 3001
    private val SMS_PERMISSION_REQUEST = 3002
    private val AUDIO_PERMISSION_REQUEST = 4001
    private val FILE_PICKER_REQUEST = 5001
    private var pendingFilePickerResult: MethodChannel.Result? = null

    private lateinit var bleManager: BleMeshManager
    private lateinit var wifiManager: WifiDirectManager
    private var mediaRecorder: MediaRecorder? = null
    private var mediaPlayer: MediaPlayer? = null
    private var activeRecordingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bleChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BLE_CHANNEL)
        bleManager = BleMeshManager(this, bleChannel)

        bleChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startScan" -> {
                    if (!hasAllPermissions(requiredBlePermissions())) {
                        requestPermissions(requiredBlePermissions(), BLE_PERMISSION_REQUEST)
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    bleManager.startScan()
                    result.success(true)
                }
                "stopScan" -> {
                    bleManager.stopScan()
                    result.success(true)
                }
                "broadcastPacket" -> {
                    if (!hasAllPermissions(requiredBlePermissions())) {
                        requestPermissions(requiredBlePermissions(), BLE_PERMISSION_REQUEST)
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val data = call.argument<String>("packetData") ?: ""
                    bleManager.broadcastPacket(data)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val wifiChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL)
        wifiManager = WifiDirectManager(this, wifiChannel)

        wifiChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverPeers" -> {
                    if (!hasAllPermissions(requiredWifiDirectPermissions())) {
                        requestPermissions(requiredWifiDirectPermissions(), WIFI_PERMISSION_REQUEST)
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    wifiManager.discoverPeers()
                    result.success(true)
                }
                "sendPacket" -> {
                    if (!hasAllPermissions(requiredWifiDirectPermissions())) {
                        requestPermissions(requiredWifiDirectPermissions(), WIFI_PERMISSION_REQUEST)
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val data = call.argument<String>("packetData") ?: ""
                    wifiManager.sendPacket(data)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val contactsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACTS_CHANNEL)
        contactsChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceContacts" -> {
                    if (!hasPermission(Manifest.permission.READ_CONTACTS)) {
                        requestPermissions(
                            arrayOf(Manifest.permission.READ_CONTACTS),
                            CONTACTS_PERMISSION_REQUEST
                        )
                    }
                    result.success(readDeviceContacts())
                }
                "sendEmergencySms" -> {
                    if (!hasPermission(Manifest.permission.SEND_SMS)) {
                        requestPermissions(
                            arrayOf(Manifest.permission.SEND_SMS),
                            SMS_PERMISSION_REQUEST
                        )
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    val contacts = call.argument<List<Map<String, Any>>>("contacts") ?: emptyList()
                    val message = call.argument<String>("message") ?: ""
                    sendEmergencySms(contacts, message)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        val fileChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.resq.app/file_access")
        fileChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFile" -> {
                    if (pendingFilePickerResult != null) {
                        result.error("FILE_PICKER_BUSY", "A file picker is already open", null)
                        return@setMethodCallHandler
                    }
                    pendingFilePickerResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(intent, FILE_PICKER_REQUEST)
                }
                "openFile" -> {
                    val path = call.argument<String>("path")
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    if (path.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    result.success(openLocalFile(path, mimeType))
                }
                else -> result.notImplemented()
            }
        }

        val voiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
        voiceChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startRecording" -> {
                    if (!hasPermission(Manifest.permission.RECORD_AUDIO)) {
                        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), AUDIO_PERMISSION_REQUEST)
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(startVoiceRecording())
                }
                "stopRecording" -> {
                    result.success(stopVoiceRecording())
                }
                "readRecordingBase64" -> {
                    val path = call.argument<String>("path")
                    result.success(readRecordingBase64(path))
                }
                "playBase64" -> {
                    val payload = call.argument<String>("payload")
                    result.success(playVoiceBase64(payload))
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != FILE_PICKER_REQUEST) return

        val result = pendingFilePickerResult ?: return
        pendingFilePickerResult = null

        if (resultCode != RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            val uri = data.data!!
            val resolver = contentResolver
            val originalName = resolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && index >= 0) cursor.getString(index) else null
            } ?: "selected_file"
            val mimeType = resolver.getType(uri) ?: "application/octet-stream"
            val safeName = originalName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val cacheFile = File(cacheDir, "resq_${System.currentTimeMillis()}_$safeName")

            resolver.openInputStream(uri).use { input ->
                if (input == null) throw IllegalStateException("Unable to read selected file")
                FileOutputStream(cacheFile).use { output -> input.copyTo(output) }
            }

            result.success(mapOf(
                "path" to cacheFile.absolutePath,
                "name" to originalName,
                "mimeType" to mimeType,
                "size" to cacheFile.length(),
            ))
        } catch (error: Exception) {
            result.error("FILE_PICK_FAILED", error.message, null)
        }
    }

    private fun openLocalFile(path: String, mimeType: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "com.resq.app.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M || checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasAllPermissions(permissions: Array<String>): Boolean {
        return permissions.all { hasPermission(it) }
    }

    private fun requiredBlePermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_ADVERTISE,
                Manifest.permission.BLUETOOTH_CONNECT,
            )
        } else {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.BLUETOOTH,
                Manifest.permission.BLUETOOTH_ADMIN,
            )
        }
    }

    private fun requiredWifiDirectPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.NEARBY_WIFI_DEVICES,
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun readDeviceContacts(): List<Map<String, String>> {
        if (!hasPermission(Manifest.permission.READ_CONTACTS)) return emptyList()

        val contacts = mutableListOf<Map<String, String>>()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )

        contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection,
            null,
            null,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
        )?.use { cursor ->
            val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val phoneIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            val seenPhones = mutableSetOf<String>()

            while (cursor.moveToNext() && contacts.size < 250) {
                val name = cursor.getString(nameIndex) ?: ""
                val phone = cursor.getString(phoneIndex)?.replace("\\s".toRegex(), "") ?: ""
                if (phone.isNotBlank() && seenPhones.add(phone)) {
                    contacts.add(
                        mapOf(
                            "name" to name,
                            "phone" to phone,
                            "relationship" to "Emergency"
                        )
                    )
                }
            }
        }

        return contacts
    }

    private fun sendEmergencySms(contacts: List<Map<String, Any>>, message: String) {
        if (message.isBlank()) return

        val smsManager = SmsManager.getDefault()
        contacts.forEach { contact ->
            val phone = contact["phone"]?.toString() ?: return@forEach
            if (phone.isNotBlank()) {
                val parts = smsManager.divideMessage(message)
                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
            }
        }
    }

    private fun startVoiceRecording(): String? {
        stopVoiceRecording()

        val outputFile = File(cacheDir, "resq_voice_${System.currentTimeMillis()}.m4a")
        activeRecordingPath = outputFile.absolutePath

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(64000)
            setAudioSamplingRate(44100)
            setOutputFile(outputFile.absolutePath)
            prepare()
            start()
        }

        return outputFile.absolutePath
    }

    private fun stopVoiceRecording(): String? {
        val path = activeRecordingPath
        val recorder = mediaRecorder ?: return path

        try {
            recorder.stop()
        } catch (_: Exception) {
        } finally {
            recorder.reset()
            recorder.release()
            mediaRecorder = null
        }

        return path
    }

    private fun readRecordingBase64(path: String?): String? {
        if (path.isNullOrBlank()) return null
        val file = File(path)
        if (!file.exists()) return null
        return Base64.encodeToString(file.readBytes(), Base64.NO_WRAP)
    }

    private fun playVoiceBase64(payload: String?): Boolean {
        if (payload.isNullOrBlank()) return false

        return try {
            val outputFile = File(cacheDir, "resq_received_voice_${System.currentTimeMillis()}.m4a")
            outputFile.writeBytes(Base64.decode(payload, Base64.NO_WRAP))

            mediaPlayer?.release()
            mediaPlayer = MediaPlayer().apply {
                setDataSource(outputFile.absolutePath)
                setOnCompletionListener {
                    it.release()
                    if (mediaPlayer == it) mediaPlayer = null
                }
                prepare()
                start()
            }
            true
        } catch (_: Exception) {
            false
        }
    }
}
