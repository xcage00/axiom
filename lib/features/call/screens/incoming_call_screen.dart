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
    final callerName = _callerInfo?['full_name'] as String? ?? 'Caller';

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
                    callerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_callerInfo == null && _error == null) ...[
                    const SizedBox(height: 14),
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Checking this call…',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],

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

                  const SizedBox(height: 48),

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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCallAction(
                        label: 'Decline',
                        icon: Icons.call_end_rounded,
                        color: AppColors.error,
                        onTap: _callAuthorized && !_working
                            ? _rejectCall
                            : null,
                      ),
                      _buildCallAction(
                        label: 'Answer',
                        icon: Icons.call_rounded,
                        color: AppColors.success,
                        onTap: _callAuthorized && !_working
                            ? _acceptCall
                            : null,
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

  Widget _buildCallAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: color.withValues(alpha: onTap == null ? .55 : 1),
            shape: const CircleBorder(),
            elevation: 8,
            shadowColor: color.withValues(alpha: .35),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 70,
                height: 70,
                child: Center(
                  child: _working
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, size: 30, color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
