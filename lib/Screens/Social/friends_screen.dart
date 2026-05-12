// ignore_for_file: deprecated_member_use, unnecessary_underscores

import 'dart:async';

import 'package:achievr_app/Screens/Social/friend_profile_screen.dart';
import 'package:achievr_app/Services/friends_service.dart';
import 'package:flutter/material.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final FriendsService _friendsService = FriendsService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounce;

  bool _isLoadingFriends = true;
  bool _isSearching = false;
  bool _isRefreshing = false;
  String? _error;

  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _searchResults = [];

  bool get _showSearchPanel => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadFriends();

    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
      _error = null;
    });

    try {
      final friends = await _friendsService.fetchAcceptedFriendProfiles();

      if (!mounted) return;

      setState(() {
        _friends = friends;
        _isLoadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load friends.\n$e';
        _isLoadingFriends = false;
      });
    }
  }

  Future<void> _refreshEverything() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await _loadFriends();

      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        await _runSearch(query);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() {});

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      if (!mounted) return;

      setState(() {
        _searchResults = [];
        _isSearching = false;
      });

      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _friendsService.searchUsersByUsername(trimmed);

      final friendUserIds = _friends
          .map((friend) => friend['other_user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final filtered = results.where((profile) {
        final id = profile['id']?.toString() ?? '';
        return !friendUserIds.contains(id);
      }).toList();

      if (!mounted) return;

      setState(() {
        _searchResults = filtered;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to search users.\n$e';
        _isSearching = false;
      });
    }
  }

  Future<void> _sendRequest(String userId) async {
    try {
      await _friendsService.sendFriendRequest(addresseeUserId: userId);

      if (!mounted) return;

      setState(() {
        _searchResults = _searchResults
            .where((profile) => profile['id']?.toString() != userId)
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _removeFriend(Map<String, dynamic> friend) async {
    final friendshipId = friend['friendship_id']?.toString();
    if (friendshipId == null || friendshipId.isEmpty) return;

    final otherProfile = friend['other_profile'] as Map<String, dynamic>?;
    final username = (otherProfile?['username'] ?? 'this friend').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16161A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Remove friend?',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Remove $username from your friends list?',
            style: const TextStyle(
              color: Color(0xFFB8B8C0),
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFFB8B8C0)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF8F8F8),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _friendsService.removeFriendship(friendshipId: friendshipId);
      await _loadFriends();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend removed.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove friend: $e')),
      );
    }
  }

  String _initialFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  Widget _avatar(String username, {double size = 48}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2B2B31),
            Color(0xFF111114),
          ],
        ),
        border: Border.all(color: Color(0xFF303038)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initialFor(username),
          style: TextStyle(
            color: const Color(0xFFF8F8F8),
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasText = _searchController.text.trim().isNotEmpty;
    final focused = _searchFocusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(_showSearchPanel ? 24 : 28),
        border: Border.all(
          color: focused ? const Color(0xFFF8F8F8) : const Color(0xFF292930),
          width: focused ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(focused ? 0.36 : 0.22),
            blurRadius: focused ? 28 : 18,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(
          color: Color(0xFFF8F8F8),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: const Color(0xFFF8F8F8),
        decoration: InputDecoration(
          hintText: 'Search friends or add someone new',
          hintStyle: const TextStyle(
            color: Color(0xFF777780),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9A9AA3),
          ),
          suffixIcon: hasText
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    _runSearch('');
                    setState(() {});
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF9A9AA3),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() {
    if (!_showSearchPanel) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      constraints: const BoxConstraints(maxHeight: 360),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF292930)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: _isSearching
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Color(0xFFF8F8F8),
                  ),
                ),
              ),
            )
          : _searchResults.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26, horizontal: 12),
                  child: Center(
                    child: Text(
                      'No users found.',
                      style: TextStyle(
                        color: Color(0xFF8C8C96),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return _buildSearchResultTile(_searchResults[index]);
                  },
                ),
    );
  }

  Widget _buildSearchResultTile(Map<String, dynamic> profile) {
    final username = (profile['username'] ?? 'Unknown').toString();
    final userId = profile['id'].toString();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FriendProfileScreen(
                userId: userId,
                isFriend: false,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF2C2C34)),
          ),
          child: Row(
            children: [
              _avatar(username, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFF8F8F8),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _sendRequest(userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8F8F8),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendTile(Map<String, dynamic> friend) {
    final otherProfile = friend['other_profile'] as Map<String, dynamic>?;
    final username = (otherProfile?['username'] ?? 'Unknown').toString();
    final otherUserId = friend['other_user_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151519),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF26262D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: otherProfile == null
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendProfileScreen(
                        userId: otherUserId,
                        isFriend: true,
                      ),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _avatar(username),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeFriend(friend),
                  tooltip: 'Remove friend',
                  icon: const Icon(
                    Icons.person_remove_alt_1_rounded,
                    color: Color(0xFF8C8C96),
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF8F8F8),
          ),
        ),
      );
    }

    if (_friends.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 22),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF151519),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF26262D)),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.group_rounded,
              color: Color(0xFF777780),
              size: 34,
            ),
            SizedBox(height: 12),
            Text(
              'No friends yet',
              style: TextStyle(
                color: Color(0xFFF8F8F8),
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Search above to add your first friend.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8C8C96),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 28, bottom: 14, left: 2),
          child: Text(
            'Friends',
            style: TextStyle(
              color: Color(0xFFF8F8F8),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ..._friends.map(_buildFriendTile),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null && _friends.isEmpty && !_isLoadingFriends) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB8B8C0)),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshEverything,
      color: const Color(0xFFF8F8F8),
      backgroundColor: const Color(0xFF151519),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        children: [
          _buildSearchBar(),
          _buildSearchPanel(),
          _buildFriendsList(),
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFF8F8F8),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF09090B),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Friends',
          style: TextStyle(
            color: Color(0xFFF8F8F8),
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFF8F8F8)),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }
}