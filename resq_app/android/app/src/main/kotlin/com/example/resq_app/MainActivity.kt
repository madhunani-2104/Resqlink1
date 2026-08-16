package com.example.resq_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.provider.ContactsContract
import android.telephony.SmsManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
    }

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
                    result.error(
                        "NOT_IMPLEMENTED",
                        "Native file picker is not configured.",
                        null
                    )
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BLE_MESH_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startScan" -> {
                    result.success(false)
                }

                "stopScan" -> {
                    result.success(true)
                }

                "startAdvertising" -> {
                    result.success(false)
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIFI_DIRECT_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "discoverPeers" -> {
                    result.success(false)
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
}