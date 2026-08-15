package com.resq.app.ble

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import com.resq.app.crypto.MeshCrypto
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class BleMeshManager(private val context: Context, private val channel: MethodChannel) {
    private val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter: BluetoothAdapter? = bluetoothManager.adapter
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scanner get() = bluetoothAdapter?.bluetoothLeScanner
    private val advertiser get() = bluetoothAdapter?.bluetoothLeAdvertiser
    private val lastReadByDevice = ConcurrentHashMap<String, Long>()

    private var gattServer: BluetoothGattServer? = null
    private var latestPacketData: String = ""
    private var isScanning = false
    private var isAdvertising = false

    companion object {
        private val SERVICE_UUID: UUID = UUID.fromString("7d2f5c10-60ef-4c1f-9c6d-1a54d950beef")
        private val PACKET_CHARACTERISTIC_UUID: UUID = UUID.fromString("7d2f5c11-60ef-4c1f-9c6d-1a54d950beef")
        private val UTF8: Charset = Charsets.UTF_8
    }

    @SuppressLint("MissingPermission")
    fun startScan() {
        if (!hasBlePermissions() || bluetoothAdapter?.isEnabled != true) return
        if (isScanning) return

        startGattServer()
        lastReadByDevice.clear()

        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(SERVICE_UUID))
                .build()
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanner?.startScan(filters, settings, scanCallback)
        isScanning = true
    }

    @SuppressLint("MissingPermission")
    fun stopScan() {
        if (!hasBlePermissions()) return
        scanner?.stopScan(scanCallback)
        isScanning = false
    }

    @SuppressLint("MissingPermission")
    fun broadcastPacket(packetData: String) {
        if (!hasBlePermissions() || bluetoothAdapter?.isEnabled != true) return

        latestPacketData = MeshCrypto.encrypt(packetData)
        startGattServer()
        startAdvertising()
    }

    @SuppressLint("MissingPermission")
    private fun startGattServer() {
        if (gattServer != null || !hasBlePermissions()) return

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val characteristic = BluetoothGattCharacteristic(
            PACKET_CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        service.addCharacteristic(characteristic)

        gattServer = bluetoothManager.openGattServer(context, gattServerCallback)
        gattServer?.addService(service)
    }

    @SuppressLint("MissingPermission")
    private fun startAdvertising() {
        if (isAdvertising || advertiser == null || !hasBlePermissions()) return

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(true)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        advertiser?.startAdvertising(settings, data, advertiseCallback)
        isAdvertising = true
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        @SuppressLint("MissingPermission")
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            if (characteristic.uuid != PACKET_CHARACTERISTIC_UUID) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_FAILURE, offset, null)
                return
            }

            val bytes = latestPacketData.toByteArray(UTF8)
            val response = if (offset < bytes.size) bytes.copyOfRange(offset, bytes.size) else ByteArray(0)
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, response)
        }
    }

    private val scanCallback = object : ScanCallback() {
        @SuppressLint("MissingPermission")
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val address = result.device?.address ?: return
            val now = System.currentTimeMillis()
            val lastRead = lastReadByDevice[address] ?: 0L
            if (now - lastRead < 5000 || !hasBlePermissions()) return
            lastReadByDevice[address] = now
            mainHandler.post {
                channel.invokeMethod(
                    "onPeerDiscovered",
                    mapOf(
                        "id" to address,
                        "name" to (result.device?.name ?: "BLE Device"),
                        "transport" to "BLE",
                        "signal" to result.rssi
                    )
                )
            }
            result.device.connectGatt(context, false, gattCallback)
        }

        override fun onScanFailed(errorCode: Int) {
            isScanning = false
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                gatt.close()
                return
            }

            if (newState == BluetoothProfile.STATE_CONNECTED) {
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                gatt.close()
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS) {
                gatt.close()
                return
            }

            val characteristic = gatt
                .getService(SERVICE_UUID)
                ?.getCharacteristic(PACKET_CHARACTERISTIC_UUID)

            if (characteristic == null) {
                gatt.close()
                return
            }

            gatt.readCharacteristic(characteristic)
        }

        override fun onCharacteristicRead(
            gatt: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS && characteristic.uuid == PACKET_CHARACTERISTIC_UUID) {
                val packetData = MeshCrypto.decrypt(characteristic.value?.toString(UTF8).orEmpty())
                if (packetData.isNotBlank() && packetData != latestPacketData) {
                    mainHandler.post {
                        channel.invokeMethod("onPacketReceived", mapOf("packetData" to packetData))
                    }
                }
            }
            gatt.close()
        }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            isAdvertising = true
        }

        override fun onStartFailure(errorCode: Int) {
            isAdvertising = false
        }
    }

    private fun hasBlePermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true

        return context.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED &&
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }
}
