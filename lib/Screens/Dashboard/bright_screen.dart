import 'package:achievr_app/Services/bright_monitoring_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BrightScreen extends StatefulWidget {
  const BrightScreen({super.key});

  @override
  State<BrightScreen> createState() => _BrightScreenState();
}

class _BrightScreenState extends State<BrightScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BrightMonitoringService _brightService = BrightMonitoringService();
  final TextEditingController _chatController = TextEditingController();

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _checkins = [];

  static const Color _bg = Color(0xFF070709);
  static const Color _card = Color(0xFF121216);
  static const Color _card2 = Color(0xFF18181E);
  static const Color _border = Color(0xFF27272F);
  static const Color _text = Color(0xFFF7F7F8);
  static const Color _muted = Color(0xFF9A9AA3);
  static const Color _faint = Color(0xFF6F6F78);

  @override
  void initState() {
    super.initState();
    _loadBrightData();
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _loadBrightData() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _error = 'No authenticated user.';
        _isLoading = false;
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isRefreshing = true;
          if (_events.isEmpty && _checkins.isEmpty) {
            _isLoading = true;
          }
          _error = null;
        });
      }

      await _brightService.monitorMissedTasks(userId: user.id);

      final results = await Future.wait([
        _brightService.getOpenEvents(userId: user.id, limit: 20),
        _brightService.getRecentCheckins(userId: user.id, limit: 10),
      ]);

      if (!mounted) return;

      setState(() {
        _events = results[0];
        _checkins = results[1];
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e, st) {
      debugPrint('BRIGHT SCREEN ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load BRIGHT.';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _dismissEvent(String eventId) async {
    await _brightService.dismissEvent(eventId: eventId);
    await _loadBrightData();
  }

  Future<void> _resolveEvent(String eventId) async {
    await _brightService.resolveEvent(eventId: eventId);
    await _loadBrightData();
  }

  Future<void> _markSeen(String eventId) async {
    await _brightService.markEventSeen(eventId: eventId);
    await _loadBrightData();
  }

  String _formatCreatedAt(dynamic value) {
    if (value == null) return '';

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return '';

    final local = parsed.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';

    return '${local.month}/${local.day}';
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return const Color(0xFFFF5C7A);
      case 'warning':
        return const Color(0xFFFFC857);
      case 'nudge':
        return const Color(0xFF7DD3FC);
      case 'info':
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _eventIcon(String eventType) {
    switch (eventType) {
      case 'missed_task_first':
        return Icons.error_outline_rounded;
      case 'missed_task_streak':
        return Icons.local_fire_department_rounded;
      case 'habit_completion_declining':
        return Icons.trending_down_rounded;
      case 'habit_completion_strong':
        return Icons.trending_up_rounded;
      case 'habit_adjustment_prompt':
        return Icons.tune_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  int get _warningCount {
    return _events.where((event) {
      final severity = (event['severity'] ?? '').toString();
      return severity == 'warning' || severity == 'critical';
    }).length;
  }

  int get _nudgeCount {
    return _events.where((event) {
      final severity = (event['severity'] ?? '').toString();
      return severity == 'nudge' || severity == 'info';
    }).length;
  }

  Widget _buildHeader() {
    final activeCount = _events.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _text,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.black,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BRIGHT',
                  style: TextStyle(
                    color: _text,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Accountability operator',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _loadBrightData,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _border),
              ),
              child: _isRefreshing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _text,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: _text,
                      size: 21,
                    ),
            ),
          ),
          if (activeCount > 0) ...[
            const SizedBox(width: 9),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFC857).withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommandCard() {
    final hasIssues = _events.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B1B22),
            Color(0xFF111115),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF2D2D36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: hasIssues
                  ? const Color(0xFFFFC857).withValues(alpha: 0.12)
                  : const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: hasIssues
                    ? const Color(0xFFFFC857).withValues(alpha: 0.35)
                    : const Color(0xFF22C55E).withValues(alpha: 0.32),
              ),
            ),
            child: Icon(
              hasIssues
                  ? Icons.priority_high_rounded
                  : Icons.check_rounded,
              color: hasIssues
                  ? const Color(0xFFFFD166)
                  : const Color(0xFF4ADE80),
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasIssues ? 'Needs attention' : 'Clear right now',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  hasIssues
                      ? 'BRIGHT found $_warningCount serious item${_warningCount == 1 ? '' : 's'} and $_nudgeCount nudge${_nudgeCount == 1 ? '' : 's'}.'
                      : 'No open accountability issues. Keep executing.',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required int count,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _border),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          if (actionText != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, color: _muted, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _faint,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final eventId = event['event_id']?.toString();
    final title = (event['title'] ?? 'BRIGHT event').toString();
    final message = (event['message'] ?? '').toString();
    final severity = (event['severity'] ?? 'info').toString();
    final status = (event['status'] ?? 'unread').toString();
    final eventType = (event['event_type'] ?? '').toString();
    final createdAt = _formatCreatedAt(event['created_at']);
    final severityColor = _severityColor(severity);

    final habit = _asMap(event['habits']);
    final habitTitle = (habit['title'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: status == 'unread'
              ? severityColor.withValues(alpha: 0.42)
              : _border,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: severityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: severityColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  _eventIcon(eventType),
                  color: severityColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.25,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (createdAt.isNotEmpty)
                          Text(
                            createdAt,
                            style: const TextStyle(
                              color: _faint,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    if (habitTitle.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        habitTitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFB7B7C0),
                          fontSize: 13,
                          height: 1.38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (eventId != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (status == 'unread') ...[
                  _actionButton(
                    label: 'Seen',
                    icon: Icons.visibility_rounded,
                    onTap: () => _markSeen(eventId),
                  ),
                  const SizedBox(width: 8),
                ],
                _actionButton(
                  label: 'Resolve',
                  icon: Icons.check_rounded,
                  onTap: () => _resolveEvent(eventId),
                ),
                const SizedBox(width: 8),
                _actionButton(
                  label: 'Dismiss',
                  icon: Icons.close_rounded,
                  muted: true,
                  onTap: () => _dismissEvent(eventId),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool muted = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 39,
          decoration: BoxDecoration(
            color: muted ? _card2 : _text,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: muted ? _border : _text,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: muted ? _muted : Colors.black,
                size: 15,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: muted ? _muted : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkinCard(Map<String, dynamic> checkin) {
    final habit = _asMap(checkin['habits']);
    final habitTitle = (habit['title'] ?? 'Task').toString();
    final reason = (checkin['reason_category'] ?? 'other')
        .toString()
        .replaceAll('_', ' ');
    final note = (checkin['user_note'] ?? '').toString();
    final shared = checkin['share_with_partners'] == true;
    final createdAt = _formatCreatedAt(checkin['created_at']);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes_rounded, color: _muted, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  habitTitle,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
              if (createdAt.isNotEmpty)
                Text(
                  createdAt,
                  style: const TextStyle(
                    color: _faint,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _pill(reason),
              _pill(shared ? 'shared with partners' : 'private'),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D10),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFF22222A)),
              ),
              child: Text(
                note,
                style: const TextStyle(
                  color: Color(0xFFB7B7C0),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _muted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: _bg.withValues(alpha: 0.98),
        border: const Border(
          top: BorderSide(color: Color(0xFF1F1F26)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: TextField(
                controller: _chatController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(
                  color: _text,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
                cursorColor: _text,
                decoration: const InputDecoration(
                  hintText: 'Ask BRIGHT...',
                  hintStyle: TextStyle(
                    color: _faint,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _handleChatSubmit,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _text,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleChatSubmit() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('BRIGHT chat is next. Monitoring is active now.'),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        color: _text,
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: _text, size: 30),
            const SizedBox(height: 10),
            Text(
              _error ?? 'Failed to load BRIGHT.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _loadBrightData,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _text,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoading();
    if (_error != null) return _buildError();

    return RefreshIndicator(
      onRefresh: _loadBrightData,
      backgroundColor: _card,
      color: _text,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _buildHeader(),
          _buildCommandCard(),
          _sectionHeader(
            title: 'Needs attention',
            count: _events.length,
          ),
          if (_events.isEmpty)
            _emptyState(
              icon: Icons.shield_moon_rounded,
              title: 'Nothing urgent',
              subtitle: 'BRIGHT will step in when your execution pattern needs attention.',
            )
          else
            ..._events.map(_eventCard),
          const SizedBox(height: 6),
          _sectionHeader(
            title: 'Recent reasons',
            count: _checkins.length,
          ),
          if (_checkins.isEmpty)
            _emptyState(
              icon: Icons.notes_rounded,
              title: 'No reasons logged',
              subtitle: 'When a task is missed, the reason will appear here.',
            )
          else
            ..._checkins.map(_checkinCard),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }
}