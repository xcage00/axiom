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
    if (receiverId.isEmpty ||
        receiverId == currentUser.id ||
        !const ['audio', 'video'].contains(callType)) {
      throw ArgumentError('Invalid call recipient or type');
    }

    final response = await _supabase
        .from('calls')
        .insert({
          'caller_id': currentUser.id,
          'receiver_id': receiverId,
          'status': 'ringing',
          'call_type': callType,
        })
        .select()
        .single();

    return response;
  }

  // Update call status
  Future<void> _updateCallStatus({
    required String callId,
    required String status,
    int? duration,
    required bool receiverOnly,
    String? expectedStatus,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not logged in');
    final updates = {
      'status': status,
      if (duration != null) 'duration': duration,
      if (status == 'ended' || status == 'missed')
        'ended_at': DateTime.now().toIso8601String(),
    };

    var query = _supabase
        .from('calls')
        .update(updates)
        .eq('id', callId)
        .or('caller_id.eq.${user.id},receiver_id.eq.${user.id}');
    if (receiverOnly) query = query.eq('receiver_id', user.id);
    if (expectedStatus != null) query = query.eq('status', expectedStatus);
    final updated = await query.select('id').maybeSingle();
    if (updated == null) {
      throw StateError('Call is not available for this account or state.');
    }
  }

  // Listen for incoming calls - returns list of calls
  Stream<List<Map<String, dynamic>>> listenForIncomingCalls(String userId) {
    return _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId);
  }

  // Get active call for user
  Future<Map<String, dynamic>?> getActiveCall(String userId) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null || currentUser.id != userId) {
      throw Exception('Cannot query calls for another account');
    }
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
    await _updateCallStatus(
      callId: callId,
      status: 'rejected',
      receiverOnly: true,
      expectedStatus: 'ringing',
    );
  }

  // Answer a call
  Future<void> answerCall(String callId) async {
    await _updateCallStatus(
      callId: callId,
      status: 'answered',
      receiverOnly: true,
      expectedStatus: 'ringing',
    );
  }

  // End a call
  Future<void> endCall(String callId, int duration) async {
    if (duration < 0) throw ArgumentError.value(duration, 'duration');
    await _updateCallStatus(
      callId: callId,
      status: 'ended',
      duration: duration,
      receiverOnly: false,
      expectedStatus: 'answered',
    );
  }
}
