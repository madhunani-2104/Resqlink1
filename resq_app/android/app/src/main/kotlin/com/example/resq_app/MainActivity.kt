package com.example.resq_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.ContactsContract
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.io.File
import java.io.FileOutputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.resq.app.ble.BleMeshManager
import com.resq.app.wifidirect.WifiDirectManager

class MainActivity : FlutterActivity() {

    companion object {

        private const val TAG = "RESQ_CONTACTS"

        private const val EMERGENCY_CONTACTS_CHANNEL =
            "resq_app/emergency_contacts"

        private const val FILE_ACCESS_CHANNEL =
            "resq_app/file_access"

        private const val BLE_MESH_CHANNEL =
            "resq_app/ble_mesh"

        private const val WIFI_DIRECT_CHANNEL =
            "resq_app/wifi_direct"

        private const val CONTACT_PERMISSION_REQUEST = 2001

        private const val SMS_PERMISSION_REQUEST = 2002
        private const val BLE_PERMISSION_REQUEST = 1001
        private const val WIFI_PERMISSION_REQUEST = 1002
        private const val FILE_PICKER_REQUEST = 5001
        private const val FILE_SAVE_REQUEST = 5002
    }

    private lateinit var bleManager: BleMeshManager
    private lateinit var wifiManager: WifiDirectManager
    private var pendingFilePickerResult: MethodChannel.Result? = null
    private var pendingFileSaveContent: String? = null

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        setupEmergencyContactsChannel(flutterEngine)
        setupFileAccessChannel(flutterEngine)
        setupBleMeshChannel(flutterEngine)
        setupWifiDirectChannel(flutterEngine)

        Log.d(TAG, "All ResQ MethodChannels registered")
    }

    // ============================================================
    // EMERGENCY CONTACT CHANNEL
    // ============================================================

    private fun setupEmergencyContactsChannel(
        flutterEngine: FlutterEngine
    ) {
        Log.d(
            TAG,
            "Registering emergency contacts channel: $EMERGENCY_CONTACTS_CHANNEL"
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EMERGENCY_CONTACTS_CHANNEL
        ).setMethodCallHandler { call, result ->

            Log.d(
                TAG,
                "Method received: ${call.method}"
            )

            when (call.method) {

                "getDeviceContacts" -> {
                    getDeviceContacts(result)
                }

                "sendEmergencySms" -> {

                    val contacts =
                        call.argument<List<Map<String, Any>>>("contacts")

                    val message =
                        call.argument<String>("message")

                    if (
                        contacts == null ||
                        message.isNullOrBlank()
                    ) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "Contacts or message is missing.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    sendEmergencySms(
                        contacts,
                        message,
                        result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ============================================================
    // READ DEVICE CONTACTS
    // ============================================================

    private fun getDeviceContacts(
        result: MethodChannel.Result
    ) {
        Log.d(TAG, "Starting device contact import")

        val permission =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.READ_CONTACTS
            )

        if (
            permission !=
            PackageManager.PERMISSION_GRANTED
        ) {
            Log.d(
                TAG,
                "READ_CONTACTS permission not granted"
            )

            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.READ_CONTACTS
                ),
                CONTACT_PERMISSION_REQUEST
            )

            result.error(
                "CONTACT_PERMISSION_DENIED",
                "READ_CONTACTS permission is required.",
                null
            )

            return
        }

        Log.d(
            TAG,
            "READ_CONTACTS permission granted"
        )

        val contacts =
            ArrayList<Map<String, Any>>()

        try {

            val projection = arrayOf(
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            )

            val cursor = contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                projection,
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME +
                    " ASC"
            )

            if (cursor == null) {
                Log.e(
                    TAG,
                    "Android returned null contacts cursor"
                )

                result.error(
                    "CONTACT_CURSOR_ERROR",
                    "Android returned a null contacts cursor.",
                    null
                )

                return
            }

            cursor.use {

                Log.d(
                    TAG,
                    "Contact cursor count = ${it.count}"
                )

                val nameIndex =
                    it.getColumnIndex(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME
                    )

                val phoneIndex =
                    it.getColumnIndex(
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    )

                while (it.moveToNext()) {

                    val name =
                        if (nameIndex >= 0) {
                            it.getString(nameIndex)
                                ?.trim()
                                ?: ""
                        } else {
                            ""
                        }

                    val phone =
                        if (phoneIndex >= 0) {
                            it.getString(phoneIndex)
                                ?.trim()
                                ?: ""
                        } else {
                            ""
                        }

                    if (phone.isNotEmpty()) {

                        val contact =
                            hashMapOf<String, Any>(
                                "name" to (
                                    if (name.isEmpty()) {
                                        "Unknown Contact"
                                    } else {
                                        name
                                    }
                                ),
                                "phone" to phone,
                                "relationship" to
                                    "Emergency Contact"
                            )

                        contacts.add(contact)

                        Log.d(
                            TAG,
                            "Contact found: $name - $phone"
                        )
                    }
                }
            }

            Log.d(
                TAG,
                "Total contacts with phone numbers: ${contacts.size}"
            )

            result.success(contacts)

        } catch (e: SecurityException) {

            Log.e(
                TAG,
                "Security exception while reading contacts",
                e
            )

            result.error(
                "CONTACT_SECURITY_ERROR",
                "Android denied access to contacts.",
                e.message
            )

        } catch (e: Exception) {

            Log.e(
                TAG,
                "Error while reading contacts",
                e
            )

            result.error(
                "CONTACT_READ_ERROR",
                "Unable to read device contacts.",
                e.message
            )
        }
    }

    // ============================================================
    // SEND EMERGENCY SMS
    // ============================================================

    private fun sendEmergencySms(
        contacts: List<Map<String, Any>>,
        message: String,
        result: MethodChannel.Result
    ) {
        val permission =
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.SEND_SMS
            )

        if (
            permission !=
            PackageManager.PERMISSION_GRANTED
        ) {

            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.SEND_SMS
                ),
                SMS_PERMISSION_REQUEST
            )

            result.error(
                "SMS_PERMISSION_DENIED",
                "SMS permission is required.",
                null
            )

            return
        }

        try {

            val smsManager =
                if (
                    Build.VERSION.SDK_INT >=
                    Build.VERSION_CODES.S
                ) {
                    getSystemService(
                        SmsManager::class.java
                    )
                } else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }

            var sentCount = 0

            for (contact in contacts) {

                val phone =
                    contact["phone"]
                        ?.toString()
                        ?.trim()
                        ?: ""

                if (phone.isEmpty()) {
                    continue
                }

                val parts =
                    smsManager.divideMessage(message)

                if (parts.size == 1) {

                    smsManager.sendTextMessage(
                        phone,
                        null,
                        message,
                        null,
                        null
                    )

                } else {

                    smsManager.sendMultipartTextMessage(
                        phone,
                        null,
                        parts,
                        null,
                        null
                    )
                }

                sentCount++
            }

            result.success(sentCount > 0)

        } catch (e: SecurityException) {

            result.error(
                "SMS_SECURITY_ERROR",
                "SMS permission was denied.",
                e.message
            )

        } catch (e: Exception) {

            result.error(
                "SMS_SEND_ERROR",
                "Unable to send emergency SMS.",
                e.message
            )
        }
    }

    // ============================================================
    // FILE ACCESS CHANNEL
    // ============================================================

    private fun setupFileAccessChannel(
        flutterEngine: FlutterEngine
    ) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FILE_ACCESS_CHANNEL
        ).setMethodCallHandler { call, result ->

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

                "saveFile" -> {
                    if (pendingFilePickerResult != null) {
                        result.error("FILE_ACCESS_BUSY", "A file operation is already open", null)
                        return@setMethodCallHandler
                    }

                    pendingFilePickerResult = result
                    pendingFileSaveContent = call.argument<String>("content") ?: ""
                    val fileName = call.argument<String>("fileName") ?: "resq_report.csv"
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "text/csv"
                        putExtra(Intent.EXTRA_TITLE, fileName)
                    }
                    startActivityForResult(intent, FILE_SAVE_REQUEST)
                }

                "openFile" -> {
                    result.success(false)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ============================================================
    // BLE MESH CHANNEL
    // ============================================================

    private fun setupBleMeshChannel(
        flutterEngine: FlutterEngine
    ) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BLE_MESH_CHANNEL
        )
        bleManager = BleMeshManager(this, channel)

        channel.setMethodCallHandler { call, result ->

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
                    result.success(true)
                }

                "startAdvertising" -> {
                    bleManager.broadcastPacket(call.argument<String>("packetData") ?: "")
                    result.success(true)
                }

                "broadcastPacket" -> {
                    if (!hasAllPermissions(requiredBlePermissions())) {
                        requestPermissions(requiredBlePermissions(), BLE_PERMISSION_REQUEST)
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    bleManager.broadcastPacket(call.argument<String>("packetData") ?: "")
                    result.success(true)
                }

                "stopAdvertising" -> {
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ============================================================
    // WIFI DIRECT CHANNEL
    // ============================================================

    private fun setupWifiDirectChannel(
        flutterEngine: FlutterEngine
    ) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIFI_DIRECT_CHANNEL
        )
        wifiManager = WifiDirectManager(this, channel)

        channel.setMethodCallHandler { call, result ->

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
                    wifiManager.sendPacket(call.argument<String>("packetData") ?: "")
                    result.success(true)
                }

                "stopPeerDiscovery" -> {
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (grantResults.isEmpty() || grantResults.any { it != PackageManager.PERMISSION_GRANTED }) {
            return
        }

        when (requestCode) {
            BLE_PERMISSION_REQUEST -> bleManager.startScan()
            WIFI_PERMISSION_REQUEST -> wifiManager.discoverPeers()
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasAllPermissions(permissions: Array<String>): Boolean {
        return permissions.all(::hasPermission)
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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == FILE_SAVE_REQUEST) {
            val result = pendingFilePickerResult ?: return
            pendingFilePickerResult = null
            val content = pendingFileSaveContent ?: ""
            pendingFileSaveContent = null

            if (resultCode != RESULT_OK || data?.data == null) {
                result.success(false)
                return
            }

            try {
                contentResolver.openOutputStream(data.data!!).use { output ->
                    if (output == null) throw IllegalStateException("Unable to open report destination")
                    output.write(content.toByteArray(Charsets.UTF_8))
                }
                result.success(true)
            } catch (error: Exception) {
                result.error("FILE_SAVE_FAILED", error.message, null)
            }
            return
        }

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

            result.success(
                mapOf(
                    "path" to cacheFile.absolutePath,
                    "name" to originalName,
                    "mimeType" to mimeType,
                    "size" to cacheFile.length(),
                )
            )
        } catch (error: Exception) {
            result.error("FILE_PICK_FAILED", error.message, null)
        }
    }
}