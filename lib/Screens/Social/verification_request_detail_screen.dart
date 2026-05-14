// ignore_for_file: use_build_context_synchronously

import 'package:achievr_app/Services/verification_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerificationRequestDetailScreen extends StatefulWidget {
  final String requestId;

  const VerificationRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<VerificationRequestDetailScreen> createState() =>
      _VerificationRequestDetailScreenState();
}

class _VerificationRequestDetailScreenState
    extends State<VerificationRequestDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final VerificationService _verificationService = VerificationService();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  Map<String, dynamic>? _request;
  Map<String, dynamic>? _habit;
  Map<String, dynamic>? _goal;
  Map<String, dynamic>? _log;
  Map<String, dynamic>? _requester;
  Map<String, dynamic>? _evidence;

  @override
  void initState() {
    super.initState();
    _loadRequest();
  }

  Future<void> _loadRequest() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final requestRow = await _supabase
          .from('log_verification_requests')
          .select('''
            request_id,
            log_id,
            habit_id,
            requester_user_id,
            verifier_user_id,
            status,
            note,
            decision_note,
            threshold_met,
            auto_eligible,
            submitted_at,
            reviewed_at,
            focus_session_id,
            evidence_snapshot_id
          ''')
          .eq('request_id', widget.requestId)
          .maybeSingle();

      if (requestRow == null) {
        throw Exception('Verification request not found.');
      }

      final request = Map<String, dynamic>.from(requestRow);

      final requesterUserId = request['requester_user_id']?.toString();
      final habitId = request['habit_id']?.toString();
      final logId = request['log_id']?.toString();
      final evidenceSnapshotId = request['evidence_snapshot_id']?.toString();

      Map<String, dynamic>? requester;
      if (requesterUserId != null && requesterUserId.isNotEmpty) {
        final profileRow = await _supabase
            .from('profiles')
            .select('id, username, public_handle')
            .eq('id', requesterUserId)
            .maybeSingle();

        if (profileRow != null) {
          requester = Map<String, dynamic>.from(profileRow);
        }
      }

      Map<String, dynamic>? habit;
      Map<String, dynamic>? goal;

      if (habitId != null && habitId.isNotEmpty) {
        final habitRow = await _supabase
            .from('habits')
            .select('''
              habit_id,
              goal_id,
              title,
              verification_type,
              duration_minutes,
              min_valid_minutes,
              base_points,
              penalty_points
            ''')
            .eq('habit_id', habitId)
            .maybeSingle();

        if (habitRow != null) {
          habit = Map<String, dynamic>.from(habitRow);

          final goalId = habit['goal_id']?.toString();
          if (goalId != null && goalId.isNotEmpty) {
            final goalRow = await _supabase
                .from('goals')
                .select('goal_id, title')
                .eq('goal_id', goalId)
                .maybeSingle();

            if (goalRow != null) {
              goal = Map<String, dynamic>.from(goalRow);
            }
          }
        }
      }

      Map<String, dynamic>? log;
      if (logId != null && logId.isNotEmpty) {
        final logRow = await _supabase
            .from('habit_logs')
            .select('''
              log_id,
              log_date,
              scheduled_start,
              scheduled_end,
              status,
              submitted_at
            ''')
            .eq('log_id', logId)
            .maybeSingle();

        if (logRow != null) {
          log = Map<String, dynamic>.from(logRow);
        }
      }

      Map<String, dynamic>? evidence;
      if (evidenceSnapshotId != null && evidenceSnapshotId.isNotEmpty) {
        evidence = await _verificationService.fetchEvidenceSnapshot(
          evidenceSnapshotId: evidenceSnapshotId,
        );
      }

      if (!mounted) return;

      setState(() {
        _request = request;
        _requester = requester;
        _habit = habit;
        _goal = goal;
        _log = log;
        _evidence = evidence;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load verification request.\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _review(bool approve) async {
    final request = _request;
    if (request == null) return;

    final requestId = request['request_id']?.toString();
    final logId = request['log_id']?.toString();
    final status = (request['status'] ?? '').toString();

    if (requestId == null || logId == null) return;

    if (status != 'pending') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This request is already $status.')),
      );
      return;
    }

    try {
      setState(() {
        _isSaving = true;
        _error = null;
      });

      if (approve) {
        await _verificationService.approveVerificationRequest(
          requestId: requestId,
          logId: logId,
        );
      } else {
        await _verificationService.rejectVerificationRequest(
          requestId: requestId,
          logId: logId,
          decisionNote: 'Rejected by verifier.',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Approved.' : 'Rejected.'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to review request.\n$e';
        _isSaving = false;
      });
    }
  }

  String _displayName(Map<String, dynamic>? profile) {
    if (profile == null) return 'Unknown user';

    final username = (profile['username'] ?? '').toString();
    if (username.isNotEmpty) return username;

    final handle = (profile['public_handle'] ?? '').toString();
    if (handle.isNotEmpty) return '@$handle';

    return 'Unknown user';
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'pending':
        return 'Pending review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'expired':
        return 'Expired';
      default:
        return raw;
    }
  }

  Color _statusColor(String raw) {
    switch (raw) {
      case 'pending':
        return const Color(0xFF81D4FA);
      case 'approved':
        return const Color(0xFF81C784);
      case 'rejected':
      case 'expired':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFFB3B3BB);
    }
  }

  Widget _card({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8F8F99),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFF5F5F5),
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildOverview() {
    final request = _request ?? {};
    final habit = _habit ?? {};
    final goal = _goal ?? {};
    final log = _log ?? {};

    final status = (request['status'] ?? 'pending').toString();
    final habitTitle = (habit['title'] ?? 'Untitled task').toString();
    final goalTitle = (goal['title'] ?? '').toString();
    final requesterName = _displayName(_requester);

    final logDate = (log['log_date'] ?? '').toString();
    final start = (log['scheduled_start'] ?? '').toString();
    final end = (log['scheduled_end'] ?? '').toString();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Review request',
                  style: TextStyle(
                    color: Color(0xFFF5F5F5),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            habitTitle,
            style: const TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (goalTitle.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              goalTitle,
              style: const TextStyle(
                color: Color(0xFF9A9AA3),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          _infoRow('Requester', requesterName),
          _infoRow('Date', logDate),
          if (start.isNotEmpty && end.isNotEmpty)
            _infoRow('Window', '$start → $end'),
          _infoRow(
            'Submitted note',
            (request['note'] ?? '').toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidence() {
    final evidence = _evidence;
    final request = _request ?? {};

    if (evidence == null) {
      return _card(
        child: const Text(
          'No evidence snapshot was attached to this request.',
          style: TextStyle(
            color: Color(0xFFB3B3BB),
            height: 1.4,
          ),
        ),
      );
    }

    final scheduled = evidence['scheduled_minutes']?.toString() ?? '--';
    final required = evidence['required_valid_minutes']?.toString() ?? '--';
    final actual = evidence['actual_valid_minutes']?.toString() ?? '--';
    final interruptions = evidence['interruption_count']?.toString() ?? '0';
    final exits = evidence['exit_count']?.toString() ?? '0';
    final thresholdMet = evidence['threshold_met'] == true;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Focus evidence',
            style: TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _infoRow('Scheduled', '$scheduled min'),
          _infoRow('Required valid', '$required min'),
          _infoRow('Actual valid', '$actual min'),
          _infoRow('App interruptions', interruptions),
          _infoRow('Focus exits', exits),
          _infoRow('Threshold met', thresholdMet ? 'Yes' : 'No'),
          if ((request['threshold_met'] ?? false) == true)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'This task reached the focus threshold and is waiting for your review.',
                style: TextStyle(
                  color: Color(0xFF81C784),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final status = (_request?['status'] ?? '').toString();
    final canReview = status == 'pending';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: (_isSaving || !canReview) ? null : () => _review(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF8A80),
                  side: const BorderSide(color: Color(0xFFFF8A80)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(_isSaving ? 'Working...' : 'Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: (_isSaving || !canReview) ? null : () => _review(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF5F5F5),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _isSaving ? 'Working...' : 'Approve',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
        if (!canReview) ...[
          const SizedBox(height: 10),
          Text(
            'This request is already ${_statusLabel(status).toLowerCase()}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9A9AA3),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF5F5F5)),
      );
    }

    if (_error != null && _request == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFF8A80),
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        _buildOverview(),
        _buildEvidence(),
        if (_error != null) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x22E57373),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE57373)),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFFF8A80),
                height: 1.35,
              ),
            ),
          ),
        ],
        _buildActions(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0C),
        title: const Text('Verification Review'),
      ),
      body: _buildBody(),
    );
  }
}