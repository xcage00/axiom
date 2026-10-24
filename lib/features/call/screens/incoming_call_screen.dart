import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../data/services/call_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;

  const IncomingCallScreen({super.key, required this.callData});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();
  Map<String, dynamic>? _callerInfo;
  bool _callAuthorized = false;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCallerInfo();
  }

  Future<void> _loadCallerInfo() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    final callId = widget.callData['id'];
    final callerId = widget.callData['caller_id'];
    final receiverId = widget.callData['receiver_id'];
    if (currentUser == null ||
        currentUser.id != receiverId ||
        callId is! String ||
        callerId is! String) {
      if (mounted)
        setState(() => _error = 'This call is not addressed to your account.');
      return;
    }
    try {
      final call = await client
          .from('calls')
          .select('id,caller_id,receiver_id,call_type,status')
          .eq('id', callId)
          .single();
      if (call['receiver_id'] != currentUser.id ||
          call['caller_id'] != callerId ||
          call['status'] != 'ringing' ||
          !['audio', 'video'].contains(call['call_type'])) {
        throw StateError('Call is no longer available.');
      }
      final response = await client
          .from('users')
          .select('full_name, username, avatar_url')
          .eq('id', callerId)
          .single();
      if (mounted)
        setState(() {
          _callerInfo = response;
          _callAuthorized = true;
        });
    } catch (_) {
      if (mounted) setState(() => _error = 'This call is no longer available.');
    }
  }

  void _acceptCall() async {
    if (!_callAuthorized || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await _callService.answerCall(widget.callData['id'] as String);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreen(
              contactId: widget.callData['caller_id'] as String,
              contactName: _callerInfo?['full_name'] ?? 'Caller',
              isVideoCall: widget.callData['call_type'] == 'video',
              callId: widget.callData['id'] as String,
              isInitiator: false,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _working = false;
          _error = 'Could not answer this call. Try again.';
        });
    }
  }

  void _rejectCall() async {
    if (!_callAuthorized || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await _callService.rejectCall(widget.callData['id'] as String);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        setState(() {
          _working = false;
          _error = 'Could not decline this call. Try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callData['call_type'] == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(gradient: AppColors.primaryGradient),
            ),

            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                    ),
                    child: ClipOval(
                      child: _callerInfo?['avatar_url'] != null
                          ? Image.network(
                              _callerInfo!['avatar_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.primary,
                                );
                              },
                            )
                          : Icon(
                              Icons.person,
                              size: 50,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Caller name
                  Text(
                    _callerInfo?['full_name'] ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Call type
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isVideo ? Icons.videocam : Icons.phone,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVideo
                            ? 'Incoming video call...'
                            : 'Incoming voice call...',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  if (_error != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Accept/Reject buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject button
                      GestureDetector(
                        onTap: _callAuthorized && !_working
                            ? _rejectCall
                            : null,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end,
                            size: 35,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Accept button
                      GestureDetector(
                        onTap: _callAuthorized && !_working
                            ? _acceptCall
                            : null,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call,
                            size: 35,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
