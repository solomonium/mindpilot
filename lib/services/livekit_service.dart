import 'package:livekit_client/livekit_client.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mindpilot/export.dart';

class LiveKitService {
  Room? _room;
  Room? get room => _room;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Track active speaking participant identities
  final List<String> _speakers = [];
  List<String> get speakers => _speakers;

  Function()? onStateChanged;

  Future<void> joinRoom({
    required String roomName,
    required String participantName,
  }) async {
    try {
      // 1. Fetch token from Firebase Cloud Functions
      final callable = FirebaseFunctions.instance.httpsCallable('getLiveKitToken');
      final result = await callable.call(<String, dynamic>{
        'roomName': roomName,
        'participantName': participantName,
      });

      final data = result.data as Map;
      final token = data['token'] as String;
      final url = data['url'] as String;

      // 2. Disconnect existing room if any
      await disconnect();

      // Configure audio options for clean communication
      final roomOptions = RoomOptions(
        defaultAudioPublishOptions: const AudioPublishOptions(
          dtx: true,
        ),
        defaultAudioCaptureOptions: const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
        ),
      );

      // 3. Connect to the room
      final room = Room(roomOptions: roomOptions);
      _room = room;

      // Setup listeners
      final listener = room.createListener();
      _setupRoomListeners(listener);

      await room.connect(url, token);
      _isConnected = true;

      // Enable microphone (publish local audio) by default on join
      await room.localParticipant?.setMicrophoneEnabled(true);
      onStateChanged?.call();

      safePrint("Connected to LiveKit room: $roomName as $participantName");
    } catch (e) {
      safePrint("Error joining LiveKit room: $e");
      rethrow;
    }
  }

  void _setupRoomListeners(EventsListener<RoomEvent> listener) {
    listener
      ..on<RoomDisconnectedEvent>((event) {
        _room = null;
        _isConnected = false;
        _speakers.clear();
        onStateChanged?.call();
        safePrint("Disconnected from LiveKit room");
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        _speakers.clear();
        for (var p in event.speakers) {
          _speakers.add(p.identity);
        }
        onStateChanged?.call();
      })
      ..on<TrackSubscribedEvent>((event) {
        safePrint("Subscribed to track: ${event.track.sid}");
      });
  }

  Future<void> toggleMicrophone(bool enabled) async {
    if (_room != null && _isConnected) {
      await _room!.localParticipant?.setMicrophoneEnabled(enabled);
      onStateChanged?.call();
    }
  }

  bool isMicrophoneEnabled() {
    return _room?.localParticipant?.isMicrophoneEnabled() ?? false;
  }

  Future<void> disconnect() async {
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
      _isConnected = false;
      _speakers.clear();
      onStateChanged?.call();
    }
  }

  bool isParticipantMuted(String identity) {
    final room = _room;
    if (room == null || !_isConnected) return true;

    if (room.localParticipant?.identity == identity) {
      return !(room.localParticipant?.isMicrophoneEnabled() ?? false);
    }

    for (var p in room.remoteParticipants.values) {
      if (p.identity == identity) {
        return !p.isMicrophoneEnabled();
      }
    }

    return true;
  }

  bool isParticipantSpeaking(String identity) {
    return _speakers.contains(identity);
  }
}
