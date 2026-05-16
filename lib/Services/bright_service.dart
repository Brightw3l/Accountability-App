import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class BrightMessage {
  const BrightMessage({
    required this.messageId,
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.actionJson,
    this.metadata,
  });

  final String messageId;
  final String conversationId;
  final String userId;
  final String role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? actionJson;
  final Map<String, dynamic>? metadata;

  factory BrightMessage.fromMap(Map<String, dynamic> map) {
    return BrightMessage(
      messageId: map['message_id'].toString(),
      conversationId: map['conversation_id'].toString(),
      userId: map['user_id'].toString(),
      role: (map['role'] ?? 'assistant').toString(),
      content: (map['content'] ?? '').toString(),
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      actionJson: map['action_json'] is Map
          ? Map<String, dynamic>.from(map['action_json'] as Map)
          : null,
      metadata: map['metadata'] is Map
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasAction => actionJson != null && actionJson!.isNotEmpty;
}

class BrightService {
  BrightService({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  String get _userId {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found.');
    }
    return user.id;
  }

  Future<void> cleanupExpiredMessages() async {
    try {
      await _supabase.rpc('cleanup_expired_bright_messages');
    } catch (e, st) {
      debugPrint('BRIGHT CLEANUP ERROR: $e');
      debugPrint('$st');
    }
  }

  Future<Map<String, dynamic>> applyHabitDurationChange({
    required String habitId,
    required int newDurationMinutes,
    required String reasonCategory,
    required String reason,
  }) async {
    final response = await _supabase.rpc(
      'bright_change_habit_duration',
      params: {
        'p_habit_id': habitId,
        'p_new_duration_minutes': newDurationMinutes,
        'p_reason_category': reasonCategory,
        'p_reason': reason,
      },
    );

    final rows = List<Map<String, dynamic>>.from(response as List);

    if (rows.isEmpty) {
      throw Exception('Bright duration change did not return a result.');
    }

    return rows.first;
  }

  Future<String> getOrCreateActiveConversation({
    String contextType = 'general',
    String? contextId,
  }) async {
    final userId = _userId;

    await cleanupExpiredMessages();

    final nowIso = DateTime.now().toUtc().toIso8601String();

    var query = _supabase
        .from('bright_conversations')
        .select('conversation_id')
        .eq('user_id', userId)
        .gt('expires_at', nowIso);

    if (contextType.isNotEmpty) {
      query = query.eq('context_type', contextType);
    }

    if (contextId != null && contextId.isNotEmpty) {
      query = query.eq('context_id', contextId);
    }

    final existingRows = await query
        .order('created_at', ascending: false)
        .limit(1);

    final conversations = List<Map<String, dynamic>>.from(existingRows);

    if (conversations.isNotEmpty) {
      return conversations.first['conversation_id'].toString();
    }

    final insertData = <String, dynamic>{
      'user_id': userId,
      'title': 'Bright',
      'context_type': contextType,
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String(),
    };

    if (contextId != null && contextId.isNotEmpty) {
      insertData['context_id'] = contextId;
    }

    final created = await _supabase
        .from('bright_conversations')
        .insert(insertData)
        .select('conversation_id')
        .single();

    return created['conversation_id'].toString();
  }

  Future<Map<String, dynamic>> generateBrightReply({
    required String message,
    required List<BrightMessage> recentMessages,
  }) async {
    final payload = {
      'message': message,
      'recent_messages': recentMessages
          .take(8)
          .map((m) => {
                'role': m.role,
                'content': m.content,
              })
          .toList(),
    };

    final response = await _supabase.functions.invoke(
      'bright-chat',
      body: payload,
    );

    if (response.data == null) {
      throw Exception('Bright returned no response.');
    }

    final data = Map<String, dynamic>.from(response.data as Map);

    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }

    return data;
  }

  Future<List<BrightMessage>> loadMessages({
    required String conversationId,
    int limit = 30,
  }) async {
    final rows = await _supabase
        .from('bright_messages')
        .select('''
          message_id,
          conversation_id,
          user_id,
          role,
          content,
          metadata,
          action_json,
          created_at
        ''')
        .eq('conversation_id', conversationId)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(rows)
        .map(BrightMessage.fromMap)
        .toList();
  }

  Future<BrightMessage> saveUserMessage({
    required String conversationId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    return _saveMessage(
      conversationId: conversationId,
      role: 'user',
      content: content,
      metadata: metadata,
    );
  }

  Future<BrightMessage> saveAssistantMessage({
    required String conversationId,
    required String content,
    Map<String, dynamic>? actionJson,
    Map<String, dynamic>? metadata,
  }) async {
    return _saveMessage(
      conversationId: conversationId,
      role: 'assistant',
      content: content,
      actionJson: actionJson,
      metadata: metadata,
    );
  }

  Future<BrightMessage> _saveMessage({
    required String conversationId,
    required String role,
    required String content,
    Map<String, dynamic>? actionJson,
    Map<String, dynamic>? metadata,
  }) async {
    final userId = _userId;

    final data = <String, dynamic>{
      'conversation_id': conversationId,
      'user_id': userId,
      'role': role,
      'content': content.trim(),
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(hours: 24))
          .toIso8601String(),
    };

    if (actionJson != null) {
      data['action_json'] = actionJson;
    }

    if (metadata != null) {
      data['metadata'] = metadata;
    }

    final row = await _supabase
        .from('bright_messages')
        .insert(data)
        .select('''
          message_id,
          conversation_id,
          user_id,
          role,
          content,
          metadata,
          action_json,
          created_at
        ''')
        .single();

    return BrightMessage.fromMap(Map<String, dynamic>.from(row));
  }

  Future<Map<String, dynamic>> applyHabitTimeChange({
    required String habitId,
    required String newStartTime,
    required String reasonCategory,
    required String reason,
  }) async {
    final response = await _supabase.rpc(
      'bright_change_habit_time',
      params: {
        'p_habit_id': habitId,
        'p_new_start_time': newStartTime,
        'p_reason_category': reasonCategory,
        'p_reason': reason,
      },
    );

    final rows = List<Map<String, dynamic>>.from(response as List);

    if (rows.isEmpty) {
      throw Exception('Bright time change did not return a result.');
    }

    return rows.first;
  }

  Future<Map<String, dynamic>> addGoalHabits({
    required String goalId,
    required List<Map<String, dynamic>> habits,
    String? defaultVerifierUserId,
    required String reason,
  }) async {
    final response = await _supabase.rpc(
      'bright_add_goal_habits',
      params: {
        'p_goal_id': goalId,
        'p_habits': habits,
        'p_default_verifier_user_id': defaultVerifierUserId,
        'p_reason': reason,
      },
    );

    final rows = List<Map<String, dynamic>>.from(response as List);

    if (rows.isEmpty) {
      throw Exception('Bright habit creation did not return a result.');
    }

    return rows.first;
  }
}