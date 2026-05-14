// ignore_for_file: unused_element_parameter, deprecated_member_use

import 'dart:async';

import 'package:achievr_app/Screens/Social/friend_profile_screen.dart';
import 'package:achievr_app/Screens/Social/friend_requests_screen.dart';
import 'package:achievr_app/Screens/Social/friends_screen.dart';
import 'package:achievr_app/Screens/Social/shared_progress_screen.dart';
import 'package:achievr_app/Screens/Social/verification_settings_screen.dart';
import 'package:achievr_app/Screens/home_screen.dart';
import 'package:achievr_app/Widgets/hold_to_refresh_wrapper.dart';
import 'package:achievr_app/Widgets/points_feedback.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with WidgetsBindingObserver {
  final SupabaseClient supabase = Supabase.instance.client;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isLoading = true;
  bool _isSigningOut = false;
  bool _isRefreshingSoftly = false;
  String? _error;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _disciplineStats;

  int _friendCount = 0;
  int _incomingRequestCount = 0;

  RealtimeChannel? _statsChannel;
  RealtimeChannel? _profileChannel;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadSocialData();
      _subscribeToLiveUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshDebounce?.cancel();

    if (_statsChannel != null) {
      supabase.removeChannel(_statsChannel!);
    }

    if (_profileChannel != null) {
      supabase.removeChannel(_profileChannel!);
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNow();
    }
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();

    _refreshDebounce = Timer(const Duration(milliseconds: 350), () {
      _refreshNow();
    });
  }

  Future<void> _refreshNow() async {
    if (!mounted) return;
    await _loadSocialData(showLoader: false);
  }

  void _subscribeToLiveUpdates() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_statsChannel != null) {
      supabase.removeChannel(_statsChannel!);
    }

    if (_profileChannel != null) {
      supabase.removeChannel(_profileChannel!);
    }

    _statsChannel = supabase.channel('live-user-discipline-stats-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_discipline_stats',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: user.id,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;

          if (newRecord.isNotEmpty && mounted) {
            setState(() {
              _disciplineStats = Map<String, dynamic>.from(newRecord);
            });
          }

          _scheduleRefresh();
        },
      )
      ..subscribe();

    _profileChannel = supabase.channel('live-profile-${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: user.id,
        ),
        callback: (payload) {
          final newRecord = payload.newRecord;

          if (newRecord.isNotEmpty && mounted) {
            setState(() {
              _profile = Map<String, dynamic>.from(newRecord);
            });
          }

          _scheduleRefresh();
        },
      )
      ..subscribe();
  }

  Future<void> _loadSocialData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      if (_isRefreshingSoftly) return;
      _isRefreshingSoftly = true;
      _error = null;
    }

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          _error = 'No authenticated user found.';
          _isLoading = false;
          _isRefreshingSoftly = false;
        });
        return;
      }

      final profileFuture = supabase
          .from('profiles')
          .select('''
            id,
            username,
            public_handle,
            plan_tier,
            strict_mode_enabled,
            current_title,
            prestige_level,
            accountability_score_visible
          ''')
          .eq('id', user.id)
          .maybeSingle();

      final statsFuture = supabase
          .from('user_discipline_stats')
          .select('''
            user_id,
            execution_points,
            current_streak
          ''')
          .eq('user_id', user.id)
          .maybeSingle();

      final friendshipsFuture = supabase
          .from('friendships')
          .select('friendship_id')
          .eq('status', 'accepted')
          .or('requester_id.eq.${user.id},addressee_id.eq.${user.id}');

      final requestsFuture = supabase
          .from('friendships')
          .select('friendship_id')
          .eq('addressee_id', user.id)
          .eq('status', 'pending');

      final results = await Future.wait<dynamic>([
        profileFuture,
        statsFuture,
        friendshipsFuture,
        requestsFuture,
      ]);

      final profileResponse = results[0] as Map<String, dynamic>?;
      final statsResponse = results[1] as Map<String, dynamic>?;
      final friendships = List<Map<String, dynamic>>.from(results[2] as List);
      final requests = List<Map<String, dynamic>>.from(results[3] as List);

      if (!mounted) return;

      setState(() {
        _profile = profileResponse;
        _disciplineStats = statsResponse;
        _friendCount = friendships.length;
        _incomingRequestCount = requests.length;
        _isLoading = false;
        _isRefreshingSoftly = false;
      });
    } catch (e, st) {
      debugPrint('SOCIAL SCREEN ERROR: $e');
      debugPrint('$st');

      if (!mounted) return;

      setState(() {
        _error = 'Failed to load social page.\n$e';
        _isLoading = false;
        _isRefreshingSoftly = false;
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

  Future<void> _openFriends() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
    );

    await _refreshNow();
  }

  Future<void> _openRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FriendRequestsScreen()),
    );

    await _refreshNow();
  }

  Future<void> _openVerification() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerificationSettingsScreen()),
    );

    await _refreshNow();
  }

  Future<void> _openVisibility() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SharedProgressScreen()),
    );

    await _refreshNow();
  }

  Future<void> _openOwnProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendProfileScreen(
          userId: user.id,
          isFriend: true,
        ),
      ),
    );

    await _refreshNow();
  }

  void _showComingSoonSetting(String title) {
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title settings can be connected next.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _username {
    final username = _profile?['username'];
    if (username is String && username.trim().isNotEmpty) {
      return username.trim();
    }
    return 'User';
  }

  String get _publicHandle {
    final handle = _profile?['public_handle'];
    if (handle is String && handle.trim().isNotEmpty) {
      return handle.trim();
    }
    return '';
  }

  String get _currentTitle {
    final title = _profile?['current_title'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }
    return 'Starter';
  }

  int get _prestigeLevel {
    final value = _profile?['prestige_level'];
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? ''}') ?? 1;
  }

  int get _executionPoints {
    final value = _disciplineStats?['execution_points'];
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  int get _currentStreak {
    final value = _disciplineStats?['current_streak'];
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  bool get _profileIsPublic {
    return _profile?['accountability_score_visible'] == true;
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(18),
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF292930)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _iconButton(
          icon: Icons.menu_rounded,
          onTap: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        const Spacer(),
        const Text(
          'Social',
          style: TextStyle(
            color: Color(0xFFF8F8F8),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),
        _profileAvatar(size: 44),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFF151519),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF292930)),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFF8F8F8),
          size: 21,
        ),
      ),
    );
  }

  Widget _profileAvatar({double size = 72}) {
    return GestureDetector(
      onTap: _openOwnProfile,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A2A31),
              Color(0xFF101013),
            ],
          ),
          border: Border.all(color: const Color(0xFF34343C)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: Text(
            _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
            style: TextStyle(
              color: const Color(0xFFF8F8F8),
              fontSize: size * 0.38,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactProfileCard() {
    return _card(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _profileAvatar(size: 68),
              Positioned(
                bottom: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'LV $_prestigeLevel',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1,
                  ),
                ),
                if (_publicHandle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '@$_publicHandle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8C8C96),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _miniBadge(_currentTitle),
                    _streakBadge(),
                    _xpBadge(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF202026),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF303038)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF8F8F8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _streakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF202026),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF303038)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Text(
          '$_currentStreak day streak',
          key: ValueKey<int>(_currentStreak),
          style: const TextStyle(
            color: Color(0xFFF8F8F8),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _xpBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF202026),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF303038)),
      ),
      child: AnimatedPointsText(
        value: _executionPoints,
        suffix: ' XP',
        style: const TextStyle(
          color: Color(0xFFF8F8F8),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSocialGrid() {
    return _card(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Accountability',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Manage the people and permissions around your progress.',
            style: TextStyle(
              color: Color(0xFF8C8C96),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _socialActionCard(
                  icon: Icons.group_rounded,
                  title: 'Friends',
                  subtitle: _friendCount == 0
                      ? 'Find and add people'
                      : '$_friendCount connected',
                  count: _friendCount > 0 ? _friendCount.toString() : null,
                  onTap: _openFriends,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _socialActionCard(
                  icon: Icons.mark_email_unread_rounded,
                  title: 'Requests',
                  subtitle: _incomingRequestCount == 0
                      ? 'No pending invites'
                      : '$_incomingRequestCount waiting',
                  count: _incomingRequestCount > 0
                      ? _incomingRequestCount.toString()
                      : null,
                  onTap: _openRequests,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _socialActionCard(
                  icon: Icons.verified_user_rounded,
                  title: 'Verification',
                  subtitle: 'Review proof settings',
                  onTap: _openVerification,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _socialActionCard(
                  icon: Icons.visibility_rounded,
                  title: 'Visibility',
                  subtitle:
                      _profileIsPublic ? 'Profile is public' : 'Profile is private',
                  onTap: _openVisibility,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _socialActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? count,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 142,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFF1D1D22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF2B2B32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25252B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF33333B)),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFF8F8F8),
                    size: 21,
                  ),
                ),
                const Spacer(),
                if (count != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      count,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF6F6F76),
                    size: 22,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF8F8F8),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF8C8C96),
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF09090B),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _drawerHeader(),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _drawerTile(
                      icon: Icons.notifications_active_rounded,
                      title: 'Reminder tones',
                      subtitle:
                          'Sounds for reminders, warnings, and missed windows',
                      onTap: () => _showComingSoonSetting('Reminder tone'),
                    ),
                    _drawerTile(
                      icon: Icons.flash_on_rounded,
                      title: 'Quick add',
                      subtitle: 'Defaults for fast habit and goal creation',
                      onTap: () => _showComingSoonSetting('Quick add'),
                    ),
                    _drawerTile(
                      icon: Icons.today_rounded,
                      title: 'Daily planning',
                      subtitle:
                          'Planning prompts, startup flow, and shutdown flow',
                      onTap: () => _showComingSoonSetting('Daily planning'),
                    ),
                    _drawerTile(
                      icon: Icons.lock_rounded,
                      title: 'Strict mode',
                      subtitle: 'Failure windows and accountability rules',
                      onTap: () => _showComingSoonSetting('Strict mode'),
                    ),
                    _drawerTile(
                      icon: Icons.palette_rounded,
                      title: 'Appearance',
                      subtitle: 'Theme, density, and profile display options',
                      onTap: () => _showComingSoonSetting('Appearance'),
                    ),
                    _drawerTile(
                      icon: Icons.person_rounded,
                      title: 'Account',
                      subtitle: 'Profile, plan, email, and security settings',
                      onTap: () => _showComingSoonSetting('Account'),
                    ),
                  ],
                ),
              ),
              _drawerTile(
                icon: Icons.logout_rounded,
                title: _isSigningOut ? 'Signing out...' : 'Sign out',
                subtitle: 'End your current session',
                isDanger: true,
                onTap: _isSigningOut ? () {} : _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF292930)),
      ),
      child: Row(
        children: [
          _profileAvatar(size: 52),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      'LV $_prestigeLevel',
                      style: const TextStyle(
                        color: Color(0xFF8C8C96),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      '•',
                      style: TextStyle(
                        color: Color(0xFF55555C),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _currentTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8C8C96),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
    );
  }

  Widget _drawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDanger ? const Color(0xFF4A2525) : const Color(0xFF292930),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isDanger ? const Color(0xFF231313) : const Color(0xFF202026),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: isDanger
                ? const Color(0xFFFF8A80)
                : const Color(0xFFF8F8F8),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isDanger
                ? const Color(0xFFFF8A80)
                : const Color(0xFFF8F8F8),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF8C8C96),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          isDanger ? Icons.logout_rounded : Icons.chevron_right_rounded,
          color: isDanger
              ? const Color(0xFFFF8A80)
              : const Color(0xFF6F6F76),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF8F8F8)),
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
              color: Color(0xFFB8B8C0),
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return HoldToRefreshWrapper(
      onRefresh: () => _loadSocialData(showLoader: false),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopBar(),
            _buildCompactProfileCard(),
            _buildSocialGrid(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF09090B),
      drawer: _settingsDrawer(),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }
}