import 'package:supabase_flutter/supabase_flutter.dart';

class CallService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new call
  Future<Map<String, dynamic>> createCall({
    required String receiverId,
    required String callType,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) throw Exception('Not logged in');

    final response = await _supabase.from('calls').insert({
      'caller_id': currentUser.id,
      'receiver_id': receiverId,
      'status': 'ringing',
      'call_type': callType,
    }).select().single();

    return response;
  }

  // Update call status
  Future<void> updateCallStatus({
    required String callId,
    required String status,
    int? duration,
  }) async {
    final updates = {
      'status': status,
      if (duration != null) 'duration': duration,
      if (status == 'ended' || status == 'missed') 'ended_at': DateTime.now().toIso8601String(),
    };

    await _supabase.from('calls').update(updates).eq('id', callId);
  }

  // Listen for incoming calls - returns list of calls
  Stream<List<Map<String, dynamic>>> listenForIncomingCalls(String userId) {
    return _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .execute();
  }

  // Get active call for user
  Future<Map<String, dynamic>?> getActiveCall(String userId) async {
    final response = await _supabase
        .from('calls')
        .select()
        .or('caller_id.eq.$userId,receiver_id.eq.$userId')
        .neq('status', 'ended')
        .neq('status', 'missed')
        .order('created_at', ascending: false)
        .limit(1);

    if (response.isEmpty) return null;
    return response.first;
  }

  // Reject a call
  Future<void> rejectCall(String callId) async {
    await updateCallStatus(callId: callId, status: 'rejected');
  }

  // Answer a call
  Future<void> answerCall(String callId) async {
    await updateCallStatus(callId: callId, status: 'answered');
  }

  // End a call
  Future<void> endCall(String callId, int duration) async {
    await updateCallStatus(callId: callId, status: 'ended', duration: duration);
  }
}