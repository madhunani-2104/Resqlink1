import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/constants/api_endpoints.dart';
import '../../core/services/preference_service.dart';
import '../../core/utils/logger.dart';

enum CallType { audio, video }
enum CallStatus { idle, outgoing, ringing, connecting, connected, ended, rejected, failed }

class IncomingCall {
  final String callId;
  final String callerId;
  final String callerName;
  final CallType type;
  const IncomingCall({required this.callId, required this.callerId, required this.callerName, required this.type});
}

class CallProvider extends ChangeNotifier {
  io.Socket? _socket;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  CallStatus _status = CallStatus.idle;
  CallType? _callType;
  String? _callId;
  String? _peerUserId;
  String? _peerName;
  IncomingCall? _incomingCall;
  String? _errorMessage;
  bool _disposed = false;

  CallStatus get status => _status;
  CallType? get callType => _callType;
  String? get peerUserId => _peerUserId;
  String? get peerName => _peerName;
  IncomingCall? get incomingCall => _incomingCall;
  String? get errorMessage => _errorMessage;
  MediaStream? get localStream => _localStream;
  bool get isVideoCall => _callType == CallType.video;
  bool get hasActiveCall => _status == CallStatus.outgoing || _status == CallStatus.ringing || _status == CallStatus.connecting || _status == CallStatus.connected;

  Future<void> connect(String userId) async {
    if (_socket?.connected == true || userId.isEmpty) return;
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      final token = await PreferenceService.getAuthToken();
      if (token == null || token.isEmpty) return;
      final socketUrl = ApiEndpoints.baseUrl.replaceFirst('/api', '');
      _socket = io.io(socketUrl, io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());
      _socket!.onConnect((_) => _socket!.emit('join_user', token));
      _socket!.on('call_invite', _onCallInvite);
      _socket!.on('call_response', _onCallResponse);
      _socket!.on('webrtc_offer', _onOffer);
      _socket!.on('webrtc_answer', _onAnswer);
      _socket!.on('webrtc_ice_candidate', _onIceCandidate);
      _socket!.on('call_end', (_) => _finishRemoteCall('Call ended by the other user.'));
      _socket!.on('call_rejected', (_) => _finishRemoteCall('Call was rejected.'));
      _socket!.on('call_peer_disconnected', (_) => _finishRemoteCall('The other user disconnected.'));
      _socket!.onConnectError((_) => _fail('Unable to connect to call signaling.'));
      _socket!.onError((error) => AppLogger.warning('Call socket error: $error', 'CallProvider'));
      _socket!.onDisconnect((_) {
        if (hasActiveCall) _finishRemoteCall('Call connection was interrupted.');
      });
      _socket!.connect();
    } catch (e) {
      _fail('Calling service could not start.');
      AppLogger.warning('Call service connection failed: $e', 'CallProvider');
    }
  }

  Future<void> startCall({required String recipientId, required String recipientName, required CallType type}) async {
    if (recipientId.isEmpty || recipientId == 'BROADCAST' || recipientId == 'RESPONDERS_OPS') {
      _fail('Calls are available only between authenticated users.');
      return;
    }
    if (_socket?.connected != true || hasActiveCall || _incomingCall != null) {
      if (_socket?.connected != true) _fail('Calling service is not connected.');
      return;
    }
    _callType = type;
    _peerUserId = recipientId;
    _peerName = recipientName;
    _callId = 'CALL-${DateTime.now().millisecondsSinceEpoch}';
    _status = CallStatus.outgoing;
    _errorMessage = null;
    notifyListeners();
    _socket!.emit('call_invite', {'callId': _callId, 'toUserId': recipientId, 'callType': type == CallType.video ? 'video' : 'audio'});
  }

  Future<void> acceptIncomingCall() async {
    final incoming = _incomingCall;
    if (incoming == null) return;
    _callId = incoming.callId;
    _peerUserId = incoming.callerId;
    _peerName = incoming.callerName;
    _callType = incoming.type;
    _incomingCall = null;
    _status = CallStatus.connecting;
    _errorMessage = null;
    notifyListeners();
    try {
      await _createPeerConnection();
      _socket?.emit('call_response', {'callId': _callId, 'toUserId': _peerUserId, 'accepted': true});
    } catch (_) {
      _socket?.emit('call_response', {'callId': _callId, 'toUserId': _peerUserId, 'accepted': false});
      _fail('Microphone/camera permission is required to accept the call.');
    }
  }

  void rejectIncomingCall() {
    final incoming = _incomingCall;
    if (incoming == null) return;
    _socket?.emit('call_response', {'callId': incoming.callId, 'toUserId': incoming.callerId, 'accepted': false});
    _incomingCall = null;
    _status = CallStatus.rejected;
    notifyListeners();
    _resetIfIdleState();
  }

  Future<void> endCall() async {
    if (_callId != null && _peerUserId != null) _socket?.emit('call_end', {'callId': _callId, 'toUserId': _peerUserId});
    await _cleanupPeerConnection();
    _status = CallStatus.ended;
    notifyListeners();
    _resetIfIdleState();
  }

  Future<void> toggleMute() async {
    final tracks = _localStream?.getAudioTracks() ?? [];
    if (tracks.isEmpty) return;
    tracks.first.enabled = !tracks.first.enabled;
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isEmpty) return;
    tracks.first.enabled = !tracks.first.enabled;
    notifyListeners();
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}], 'sdpSemantics': 'unified-plan'});
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate == null || _callId == null || _peerUserId == null) return;
      _socket?.emit('webrtc_ice_candidate', {'callId': _callId, 'toUserId': _peerUserId, 'candidate': candidate.toMap()});
    };
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        notifyListeners();
      }
    };
    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _status = CallStatus.connected;
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed || state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _finishRemoteCall('The call connection was interrupted.');
      }
    };
    _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': _callType == CallType.video ? {'facingMode': 'user', 'width': {'ideal': 640}, 'height': {'ideal': 480}} : false});
    localRenderer.srcObject = _localStream;
    for (final track in _localStream!.getTracks()) await _peerConnection!.addTrack(track, _localStream!);
  }

  Future<void> _sendOffer() async {
    if (_peerConnection == null || _callId == null || _peerUserId == null) return;
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    _socket?.emit('webrtc_offer', {'callId': _callId, 'toUserId': _peerUserId, 'sdp': offer.toMap()});
  }

  void _onCallInvite(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      if (_incomingCall != null || hasActiveCall) {
        _socket?.emit('call_response', {'callId': data['callId'], 'toUserId': data['fromUserId'], 'accepted': false});
        return;
      }
      _incomingCall = IncomingCall(callId: data['callId'].toString(), callerId: data['fromUserId'].toString(), callerName: data['callerName']?.toString() ?? 'ResQ User', type: data['callType'] == 'video' ? CallType.video : CallType.audio);
      _status = CallStatus.ringing;
      notifyListeners();
    } catch (e) {
      AppLogger.warning('Invalid call invitation: $e', 'CallProvider');
    }
  }

  Future<void> _onCallResponse(dynamic raw) async {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['callId']?.toString() != _callId) return;
      if (data['accepted'] != true) {
        _status = CallStatus.rejected;
        await _cleanupPeerConnection();
        notifyListeners();
        _resetIfIdleState();
        return;
      }
      _status = CallStatus.connecting;
      notifyListeners();
      await _createPeerConnection();
      await _sendOffer();
    } catch (_) {
      _fail('Unable to establish the call. Check microphone/camera permissions.');
    }
  }

  Future<void> _onOffer(dynamic raw) async {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['callId']?.toString() != _callId || _peerConnection == null) return;
      final sdp = Map<String, dynamic>.from(data['sdp'] as Map);
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp['sdp']?.toString(), sdp['type']?.toString()));
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      _socket?.emit('webrtc_answer', {'callId': _callId, 'toUserId': _peerUserId, 'sdp': answer.toMap()});
    } catch (_) {
      _fail('Unable to establish the audio/video connection.');
    }
  }

  Future<void> _onAnswer(dynamic raw) async {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['callId']?.toString() != _callId) return;
      final sdp = Map<String, dynamic>.from(data['sdp'] as Map);
      await _peerConnection?.setRemoteDescription(RTCSessionDescription(sdp['sdp']?.toString(), sdp['type']?.toString()));
    } catch (_) {
      _fail('Unable to complete the call negotiation.');
    }
  }

  Future<void> _onIceCandidate(dynamic raw) async {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['callId']?.toString() != _callId) return;
      final candidate = Map<String, dynamic>.from(data['candidate'] as Map);
      await _peerConnection?.addCandidate(RTCIceCandidate(candidate['candidate']?.toString(), candidate['sdpMid']?.toString(), candidate['sdpMLineIndex'] is int ? candidate['sdpMLineIndex'] as int : null));
    } catch (e) {
      AppLogger.warning('Invalid ICE candidate: $e', 'CallProvider');
    }
  }

  Future<void> _cleanupPeerConnection() async {
    try {
      for (final track in _localStream?.getTracks() ?? <MediaStreamTrack>[]) track.stop();
      await _localStream?.dispose();
      _localStream = null;
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await _peerConnection?.close();
      _peerConnection = null;
    } catch (e) {
      AppLogger.warning('Call cleanup error: $e', 'CallProvider');
    }
  }

  void _finishRemoteCall(String message) {
    if (!hasActiveCall && _incomingCall == null) return;
    _cleanupPeerConnection();
    _incomingCall = null;
    _status = CallStatus.ended;
    _errorMessage = message;
    notifyListeners();
    _resetIfIdleState();
  }

  void _fail(String message) {
    if (_callId != null && _peerUserId != null && _status != CallStatus.idle) {
      _socket?.emit('call_end', {'callId': _callId, 'toUserId': _peerUserId});
    }
    _cleanupPeerConnection();
    _incomingCall = null;
    _status = CallStatus.failed;
    _errorMessage = message;
    notifyListeners();
    _resetIfIdleState();
  }

  void _resetIfIdleState() {
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (_disposed) return;
      if (_status == CallStatus.ended || _status == CallStatus.rejected || _status == CallStatus.failed) {
        _status = CallStatus.idle;
        _callId = null;
        _peerUserId = null;
        _peerName = null;
        _callType = null;
        _errorMessage = null;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _socket?.disconnect();
    _socket?.dispose();
    _cleanupPeerConnection();
    localRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }
}
