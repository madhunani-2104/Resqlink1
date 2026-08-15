package com.resq.app.wifidirect

import android.Manifest
import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pInfo
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.resq.app.crypto.MeshCrypto
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.Collections
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors

class WifiDirectManager(private val context: Context, private val channel: MethodChannel) {
    private val manager = context.getSystemService(Context.WIFI_P2P_SERVICE) as WifiP2pManager
    private val p2pChannel = manager.initialize(context, Looper.getMainLooper(), null)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newCachedThreadPool()
    private val clients = Collections.synchronizedList(mutableListOf<Socket>())
    private val pendingPackets = ConcurrentLinkedQueue<String>()

    private var receiverRegistered = false
    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var lastConnectedAddress: String? = null

    companion object {
        private const val PORT = 8988
        private const val SOCKET_TIMEOUT_MS = 8000
    }

    @SuppressLint("MissingPermission")
    fun discoverPeers() {
        if (!hasWifiDirectPermissions()) return
        registerReceiverIfNeeded()

        manager.discoverPeers(p2pChannel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = Unit
            override fun onFailure(reason: Int) = Unit
        })
    }

    fun sendPacket(packetData: String) {
        if (packetData.isBlank()) return

        val sent = writeToOpenSockets(packetData)
        if (!sent) {
            pendingPackets.add(packetData)
            discoverPeers()
        }
    }

    @SuppressLint("MissingPermission")
    private fun connectToFirstPeer(peers: Collection<WifiP2pDevice>) {
        if (!hasWifiDirectPermissions()) return
        val device = peers.firstOrNull() ?: return

        val config = WifiP2pConfig().apply {
            deviceAddress = device.deviceAddress
        }

        manager.connect(p2pChannel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() = Unit
            override fun onFailure(reason: Int) = Unit
        })
    }

    private fun handleConnectionInfo(info: WifiP2pInfo) {
        if (!info.groupFormed) return

        if (info.isGroupOwner) {
            startServer()
        } else {
            val ownerAddress = info.groupOwnerAddress?.hostAddress ?: return
            if (ownerAddress != lastConnectedAddress || clientSocket?.isConnected != true) {
                connectToOwner(ownerAddress)
            }
        }
    }

    private fun startServer() {
        if (serverSocket != null) return

        executor.execute {
            try {
                serverSocket = ServerSocket(PORT)
                while (!serverSocket!!.isClosed) {
                    val socket = serverSocket!!.accept()
                    clients.add(socket)
                    startSocketReader(socket)
                    flushPendingPackets()
                }
            } catch (_: Exception) {
                serverSocket = null
            }
        }
    }

    private fun connectToOwner(address: String) {
        lastConnectedAddress = address

        executor.execute {
            try {
                val socket = Socket()
                socket.bind(null)
                socket.connect(InetSocketAddress(address, PORT), SOCKET_TIMEOUT_MS)
                clientSocket = socket
                startSocketReader(socket)
                flushPendingPackets()
            } catch (_: Exception) {
                clientSocket = null
            }
        }
    }

    private fun startSocketReader(socket: Socket) {
        executor.execute {
            try {
                val reader = BufferedReader(InputStreamReader(socket.getInputStream()))
                while (!socket.isClosed) {
                    val packetData = MeshCrypto.decrypt(reader.readLine() ?: break)
                    if (packetData.isNotBlank()) {
                        mainHandler.post {
                            channel.invokeMethod("onP2pPacketReceived", mapOf("packetData" to packetData))
                        }
                    }
                }
            } catch (_: Exception) {
                clients.remove(socket)
                if (clientSocket == socket) clientSocket = null
            }
        }
    }

    private fun writeToOpenSockets(packetData: String): Boolean {
        var sent = false

        synchronized(clients) {
            val iterator = clients.iterator()
            while (iterator.hasNext()) {
                val socket = iterator.next()
                if (writeToSocket(socket, packetData)) {
                    sent = true
                } else {
                    iterator.remove()
                }
            }
        }

        val client = clientSocket
        if (client != null && writeToSocket(client, packetData)) {
            sent = true
        }

        return sent
    }

    private fun writeToSocket(socket: Socket, packetData: String): Boolean {
        return try {
            if (!socket.isConnected || socket.isClosed) return false
            val writer = PrintWriter(socket.getOutputStream(), true)
            writer.println(MeshCrypto.encrypt(packetData))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun flushPendingPackets() {
        while (pendingPackets.isNotEmpty()) {
            val packet = pendingPackets.poll() ?: break
            if (!writeToOpenSockets(packet)) {
                pendingPackets.add(packet)
                break
            }
        }
    }

    private fun registerReceiverIfNeeded() {
        if (receiverRegistered) return

        val filter = IntentFilter().apply {
            addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
            addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
        }

        context.registerReceiver(receiver, filter)
        receiverRegistered = true
    }

    private val receiver = object : BroadcastReceiver() {
        @SuppressLint("MissingPermission")
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                    if (!hasWifiDirectPermissions()) return
                    manager.requestPeers(p2pChannel) { peerList ->
                        peerList.deviceList.forEach { device ->
                            mainHandler.post {
                                channel.invokeMethod(
                                    "onPeerDiscovered",
                                    mapOf(
                                        "id" to device.deviceAddress,
                                        "name" to device.deviceName,
                                        "transport" to "Wi-Fi Direct",
                                        "signal" to device.status
                                    )
                                )
                            }
                        }
                        connectToFirstPeer(peerList.deviceList)
                    }
                }
                WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                    manager.requestConnectionInfo(p2pChannel) { info ->
                        handleConnectionInfo(info)
                    }
                }
            }
        }
    }

    private fun hasWifiDirectPermissions(): Boolean {
        val locationGranted =
            context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return locationGranted
        }

        return locationGranted &&
            context.checkSelfPermission(Manifest.permission.NEARBY_WIFI_DEVICES) == PackageManager.PERMISSION_GRANTED
    }
}
