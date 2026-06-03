import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String contactId;
  final String contactName;
  final bool isVideoCall;
  final String callId;
  final bool isInitiator;

  const CallScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.isVideoCall,
    required this.callId,
    required this.isInitiator,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  bool _isCallActive = false;
  
  // Video renderers
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  
  // Signaling WebSocket
  WebSocketChannel? _channel;
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _connectWebSocket();
    _listenForCallStatus();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _cleanup();
    super.dispose();
  }

  void _initRenderers() {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();
    _localRenderer!.initialize();
    _remoteRenderer!.initialize();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isCallActive) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _listenForCallStatus() {
    Supabase.instance.client
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', widget.callId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final call = data.first;
            if (call['status'] == 'ended' && mounted) {
              _endCall();
            }
            if (call['status'] == 'answered' && !_isCallActive && mounted) {
              setState(() {
                _isCallActive = true;
              });
              _startCallTimer();
            }
          }
        });
  }

  Future<void> _connectWebSocket() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final wsUrl = 'ws://192.168.1.69:8080';
    
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    
    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      _handleSignalingMessage(data);
    }, onDone: () {
      print('WebSocket closed');
      _isWebSocketConnected = false;
    }, onError: (error) {
      print('WebSocket error: $error');
    });
    
    _isWebSocketConnected = true;
    
    // Join room
    final joinMessage = {
      'type': 'join',
      'room': widget.callId,
      'userId': currentUser!.id,
    };
    _channel!.sink.add(jsonEncode(joinMessage));
    
    if (widget.isInitiator) {
      _initWebRTC();
    }
  }

  void _handleSignalingMessage(Map<String, dynamic> data) {
    switch (data['type']) {
      case 'offer':
        _handleOffer(data);
        break;
      case 'answer':
        _handleAnswer(data);
        break;
      case 'candidate':
        _handleCandidate(data);
        break;
    }
  }

  Future<void> _initWebRTC() async {
    try {
      Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      };

      _peerConnection = await createPeerConnection(configuration);

      // Get local media stream
      Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': widget.isVideoCall,
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      
      if (_localStream != null && _localRenderer != null) {
        _localRenderer!.srcObject = _localStream;
        _peerConnection!.addStream(_localStream!);
      }

      // Handle remote stream
      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty && mounted) {
          setState(() {
            _remoteStream = event.streams[0];
            if (_remoteRenderer != null) {
              _remoteRenderer!.srcObject = _remoteStream;
            }
            _isConnected = true;
          });
        }
      };

      // Handle ICE candidates
      _peerConnection!.onIceCandidate = (candidate) {
        if (_isWebSocketConnected && _channel != null) {
          _channel!.sink.add(jsonEncode({
            'type': 'candidate',
            'candidate': candidate.toMap(),
          }));
        }
      };

      // Create and send offer
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      if (_isWebSocketConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({
          'type': 'offer',
          'sdp': offer.sdp,
        }));
      }

    } catch (e) {
      print('Error initializing WebRTC: $e');
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> data) async {
    try {
      if (_peerConnection == null) {
        Map<String, dynamic> configuration = {
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ]
        };
        _peerConnection = await createPeerConnection(configuration);
        
        // Get local stream
        Map<String, dynamic> mediaConstraints = {
          'audio': true,
          'video': widget.isVideoCall,
        };
        _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
        if (_localStream != null && _localRenderer != null) {
          _localRenderer!.srcObject = _localStream;
          _peerConnection!.addStream(_localStream!);
        }
        
        _peerConnection!.onTrack = (event) {
          if (event.streams.isNotEmpty && mounted) {
            setState(() {
              _remoteStream = event.streams[0];
              if (_remoteRenderer != null) {
                _remoteRenderer!.srcObject = _remoteStream;
              }
              _isConnected = true;
            });
          }
        };
        
        _peerConnection!.onIceCandidate = (candidate) {
          if (_isWebSocketConnected && _channel != null) {
            _channel!.sink.add(jsonEncode({
              'type': 'candidate',
              'candidate': candidate.toMap(),
            }));
          }
        };
      }
      
      RTCSessionDescription offer = RTCSessionDescription(data['sdp'], 'offer');
      await _peerConnection!.setRemoteDescription(offer);
      
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      
      if (_isWebSocketConnected && _channel != null) {
        _channel!.sink.add(jsonEncode({
          'type': 'answer',
          'sdp': answer.sdp,
        }));
      }
      
      // Mark call as answered in database
      await _callService.answerCall(widget.callId);
      
    } catch (e) {
      print('Error handling offer: $e');
    }
  }

  Future<void> _handleAnswer(Map<String, dynamic> data) async {
    try {
      RTCSessionDescription answer = RTCSessionDescription(data['sdp'], 'answer');
      await _peerConnection!.setRemoteDescription(answer);
      
      // Mark call as answered in database
      await _callService.answerCall(widget.callId);
      
    } catch (e) {
      print('Error handling answer: $e');
    }
  }

  Future<void> _handleCandidate(Map<String, dynamic> data) async {
    try {
      final candidateMap = data['candidate'];
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      print('Error adding ICE candidate: $e');
    }
  }

  Future<void> _toggleMute() async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !_isMuted;
      }
      setState(() {
        _isMuted = !_isMuted;
      });
    }
  }

  Future<void> _toggleSpeaker() async {
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  Future<void> _toggleCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = !track.enabled;
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    }
  }

  void _endCall() async {
    if (_callTimer != null && _callTimer!.isActive) {
      final durationSeconds = _callDuration.inSeconds;
      await _callService.endCall(widget.callId, durationSeconds);
    }
    _cleanup();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _cleanup() async {
    _callTimer?.cancel();
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    await _localRenderer?.dispose();
    await _remoteRenderer?.dispose();
    _channel?.sink.close();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video
          if (_remoteStream != null && _remoteRenderer != null)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer!,
                mirror: false,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.contactName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Ringing...',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Local video preview (picture-in-picture)
          if (widget.isVideoCall && _localStream != null && _localRenderer != null)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    _localRenderer!,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Call controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute button
                  _buildControlButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onPressed: _toggleMute,
                    color: _isMuted ? AppColors.error : Colors.white70,
                  ),
                  
                  // Speaker button (audio call only)
                  if (!widget.isVideoCall)
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                      onPressed: _toggleSpeaker,
                      color: Colors.white70,
                    ),
                  
                  // End call button
                  _buildControlButton(
                    icon: Icons.call_end,
                    onPressed: _endCall,
                    color: AppColors.error,
                    isSpecial: true,
                  ),
                  
                  // Camera toggle (video call only)
                  if (widget.isVideoCall)
                    _buildControlButton(
                      icon: Icons.cameraswitch,
                      onPressed: _switchCamera,
                      color: Colors.white70,
                    ),
                  
                  // Video toggle (video call only)
                  if (widget.isVideoCall)
                    _buildControlButton(
                      icon: Icons.videocam,
                      onPressed: _toggleCamera,
                      color: Colors.white70,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool isSpecial = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isSpecial ? color : Colors.white24,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isSpecial ? Colors.white : color,
          size: 28,
        ),
      ),
    );
  }
}