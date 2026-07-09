import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  final String appId = 'f03d6138664549958dee6251274b57e9';

  Future<void> initialize() async {
    if (_engine != null) return;

    // Request permissions
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    await _engine!.enableVideo();
    await _engine!.startPreview();
  }

  Future<void> joinChannel(String channelId, int uid, {Function(int)? onUserJoined, Function(int)? onUserOffline}) async {
    if (_engine == null) await initialize();

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('AGORA: Local user ${connection.localUid} joined channel');
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('AGORA: Remote user $remoteUid joined channel');
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('AGORA: Remote user $remoteUid left channel');
          onUserOffline?.call(remoteUid);
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('AGORA Error: $err, $msg');
        },
      ),
    );

    await _engine!.joinChannel(
      token: '', // Use empty string if no token security is enabled in Agora Console for development
      channelId: channelId,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
      ),
    );
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> toggleMic(bool enabled) async {
    await _engine?.muteLocalAudioStream(!enabled);
  }

  Future<void> toggleCamera(bool enabled) async {
    await _engine?.muteLocalVideoStream(!enabled);
  }

  Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }

  RtcEngine? get engine => _engine;
}

final agoraService = AgoraService();
