import 'package:achievr_app/Screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSigningOut = false;
  String? _error;

  Map<String, dynamic>? _profile;
  int _allTimeDone = 0;
  int _activeGoals = 0;
  int _activeHabits = 0;

  @override
  void initState() {
    super.initState();
    _loadMoreData();
  }

  Future<void> _loadMoreData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No authenticated user found.';
          _isLoading = false;
        });
        return;
      }

      final profileResponse = await supabase
          .from('profiles')
          .select('username, plan_tier, strict_mode_enabled, wake_time, sleep_time')
          .eq('id', user.id)
          .maybeSingle();

      final goalsResponse = await supabase
          .from('goals')
          .select('goal_id')
          .eq('user_id', user.id)
          .eq('active', true);

      final goals = List<Map<String, dynamic>>.from(goalsResponse);

      int activeHabits = 0;

      if (goals.isNotEmpty) {
        final goalIds = goals.map((goal) => goal['goal_id'].toString()).toList();

        final habitsResponse = await supabase
            .from('habits')
            .select('habit_id')
            .inFilter('goal_id', goalIds)
            .eq('active', true);

        activeHabits = List<Map<String, dynamic>>.from(habitsResponse).length;
      }

      final allDoneResponse = await supabase
          .from('habit_logs')
          .select('log_id')
          .eq('user_id', user.id)
          .eq('status', 'done');

      final allDone = List<Map<String, dynamic>>.from(allDoneResponse);

      if (!mounted) return;

      setState(() {
        _profile = profileResponse;
        _activeGoals = goals.length;
        _activeHabits = activeHabits;
        _allTimeDone = allDone.length;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('MORE SCREEN ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load account data.\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() {
        _isSigningOut = true;
      });

      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      debugPrint('SIGN OUT ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isSigningOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sign out.')),
      );
    }
  }

  String get _username {
    final username = _profile?['username'];
    if (username is String && username.trim().isNotEmpty) {
      return username.trim();
    }
    return 'User';
  }

  String get _planTier {
    final tier = _profile?['plan_tier'];
    if (tier is String && tier.trim().isNotEmpty) {
      return tier.trim();
    }
    return 'free';
  }

  String get _wakeTime {
    final wake = _profile?['wake_time'];
    return wake?.toString() ?? '--:--';
  }

  String get _sleepTime {
    final sleep = _profile?['sleep_time'];
    return sleep?.toString() ?? '--:--';
  }

  bool get _strictMode => _profile?['strict_mode_enabled'] == true;

  Widget _buildSectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFF9A9AA3),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101013),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9A9AA3),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More',
            style: TextStyle(
              color: Color(0xFFF5F5F5),
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Account, settings, system preferences, and your all-time productivity snapshot.',
            style: TextStyle(
              color: Color(0xFFB3B3BB),
              height: 1.45,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMetricChip(
                  label: 'All-Time Done',
                  value: '$_allTimeDone',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricChip(
                  label: 'Active Goals',
                  value: '$_activeGoals',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Profile',
            subtitle: 'Your account and current discipline setup.',
          ),
          _buildInfoRow('Username', _username),
          _buildInfoRow('Plan', _planTier),
          _buildInfoRow('Strict mode', _strictMode ? 'Enabled' : 'Disabled'),
          _buildInfoRow('Wake time', _wakeTime),
          _buildInfoRow('Sleep time', _sleepTime),
        ],
      ),
    );
  }

  Widget _buildProductivityCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Productivity snapshot',
            subtitle: 'A high-level view of your current system footprint.',
          ),
          Row(
            children: [
              Expanded(
                child: _buildMetricChip(
                  label: 'Active Habits',
                  value: '$_activeHabits',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricChip(
                  label: 'Completed',
                  value: '$_allTimeDone',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Settings',
            subtitle: 'These can become interactive settings screens later.',
          ),
          _buildPlaceholderTile(
            icon: Icons.notifications_none,
            title: 'Notifications',
            subtitle: 'Reminder and alert preferences',
          ),
          _buildPlaceholderTile(
            icon: Icons.shield_outlined,
            title: 'Verification rules',
            subtitle: 'Manual, location, and future verification settings',
          ),
          _buildPlaceholderTile(
            icon: Icons.schedule,
            title: 'Schedule preferences',
            subtitle: 'Execution windows, grace periods, and timing behavior',
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF17171A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            'Account actions',
            subtitle: 'Session and account-level controls.',
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSigningOut ? null : _signOut,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5F5F5),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFF2A2A2F),
                disabledForegroundColor: const Color(0xFF6F6F76),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.logout),
              label: Text(
                _isSigningOut ? 'Signing Out...' : 'Sign Out',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101013),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF9A9AA3),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF5F5F5),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9A9AA3),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: Color(0xFF6F6F76),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101013),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232329)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9A9AA3),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFF5F5F5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF5F5F5),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB3B3BB),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMoreData,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      edgeOffset: 8,
      displacement: 72,
      color: const Color(0xFF121214),
      backgroundColor: const Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopCard(),
            _buildProfileCard(),
            _buildProductivityCard(),
            _buildSettingsCard(),
            _buildAccountActionsCard(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0C),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }
}