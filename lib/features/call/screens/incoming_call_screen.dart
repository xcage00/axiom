import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/services/call_service.dart';
import 'call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final Map<String, dynamic> callData;

  const IncomingCallScreen({
    super.key,
    required this.callData,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();
  Map<String, dynamic>? _callerInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCallerInfo();
  }

  Future<void> _loadCallerInfo() async {
    final callerId = widget.callData['caller_id'];
    final response = await Supabase.instance.client
        .from('users')
        .select('full_name, username, avatar_url')
        .eq('id', callerId)
        .single();

    setState(() {
      _callerInfo = response;
      _isLoading = false;
    });
  }

  void _acceptCall() async {
    await _callService.answerCall(widget.callData['id']);
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            contactId: widget.callData['caller_id'],
            contactName: _callerInfo?['full_name'] ?? 'Caller',
            isVideoCall: widget.callData['call_type'] == 'video',
            callId: widget.callData['id'],
            isInitiator: false,
          ),
        ),
      );
    }
  }

  void _rejectCall() async {
    await _callService.rejectCall(widget.callData['id']);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final isVideo = widget.callData['call_type'] == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
              ),
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
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3,
                      ),
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
                        isVideo ? 'Incoming video call...' : 'Incoming voice call...',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Accept/Reject buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Reject button
                      GestureDetector(
                        onTap: _rejectCall,
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
                        onTap: _acceptCall,
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