import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/app_colors.dart';
import '../chat/chat_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _acceptingPostId;
  Map<String, dynamic>? _cachedUserProfile;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _getUserProfile();
    if (mounted) {
      setState(() => _cachedUserProfile = profile);
    }
  }

  // TIME LEFT
  String _timeLeft(Timestamp expiresAt) {
    final diff = expiresAt.toDate().difference(DateTime.now());

    if (diff.inMinutes <= 0) return 'Expired';
    if (diff.inHours < 1) return '${diff.inMinutes} min left';
    return '${diff.inHours} hrs left';
  }

  String formatTime(Timestamp ts) {
    final date = ts.toDate();
    int hour = date.hour > 12 ? date.hour - 12 : date.hour;
    if (hour == 0) hour = 12;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute $amPm';
  }

  // GET USER PROFILE
  Future<Map<String, dynamic>?> _getUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    return doc.data();
  }

  Future<void> _confirmAccept(BuildContext context, String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Accept donation?'),
        content: const Text(
          'Do you want to accept this donation?\n'
          'Once accepted, it will be visible only to you and the donor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _acceptingPostId = postId);
      if (!context.mounted) return;
      await _acceptPost(postId, context);
      if (mounted) setState(() => _acceptingPostId = null);
    }
  }

  Future<void> _acceptPost(String postId, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(postRef);
        if (!snap.exists) throw 'Post not found';
        final data = snap.data() as Map<String, dynamic>;
        if (data['status'] != 'available') throw 'Already accepted';

        tx.update(postRef, {
          'status': 'accepted',
          'acceptedBy': user.uid,
          'acceptedAt': Timestamp.now(),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donation accepted! Check Donees tab.'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Builder(
        builder: (context) {
          final userData = _cachedUserProfile;
          final userDistrict = userData?['district'] ?? '';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                floating: true,
                pinned: true,
                elevation: 0,
                backgroundColor: AppColors.primaryGreen,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cachedUserProfile == null
                                ? Shimmer.fromColors(
                                    baseColor: Colors.white24,
                                    highlightColor: Colors.white54,
                                    child: Container(
                                      height: 16,
                                      width: 120,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Hi, ${_cachedUserProfile!['name'] ?? 'Kind Soul'}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            const Text(
                              'Find a donation near you',
                              style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.normal),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ChatListScreen()),
                          );
                        },
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                sliver: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('status', isEqualTo: 'available')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return SliverToBoxAdapter(child: Center(child: Text('Error: ${snapshot.error}')));
                    if (!snapshot.hasData) return SliverToBoxAdapter(child: _buildSkeletonList());

                    final now = DateTime.now();
                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
                      return expiresAt.isAfter(now);
                    }).toList();

                    if (docs.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState());

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final List images = data['images'] ?? [];
                          final isOwnPost = data['userId'] == currentUser?.uid;
                          final isNearby = data['district'] == userDistrict;

                          return _buildDonationCard(
                            context,
                            doc.id,
                            data,
                            images,
                            isOwnPost,
                            isNearby,
                          );
                        },
                        childCount: docs.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDonationCard(
    BuildContext context,
    String postId,
    Map<String, dynamic> data,
    List images,
    bool isOwnPost,
    bool isNearby,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        PageView(
                          children: images.map((url) => Container(
                            color: Colors.grey.shade100, // Background for mismatched ratios
                            child: Image.network(
                              url,
                              fit: BoxFit.contain, // Shows full image without cropping
                              alignment: Alignment.center,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
                              ),
                            ),
                          )).toList(),
                        ),
                        // Gradient Overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.3),
                                ],
                                stops: const [0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isNearby)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('NEARBY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _timeLeft(data['expiresAt']),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        data['title'] ?? '',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                    ),
                    if (isOwnPost)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.dangerRed, size: 22),
                        onPressed: () => _deletePost(context, postId),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data['description'] ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.history, color: Colors.grey.shade400, size: 16),
                    const SizedBox(width: 4),
                    Text(formatTime(data['createdAt']), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.timer_outlined, color: Colors.orange.shade400, size: 16),
                    const SizedBox(width: 4),
                    Text(_timeLeft(data['expiresAt']), style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Icon(Icons.location_on_outlined, color: Colors.grey.shade400, size: 16),
                    const SizedBox(width: 4),
                    Text(data['district'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
                if (!isOwnPost) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _acceptingPostId == postId ? null : () => _confirmAccept(context, postId),
                      child: _acceptingPostId == postId
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Accept Donation', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(BuildContext context, String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This donation post will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.dangerRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
    }
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(4, (index) => _buildSkeletonCard()),
    );
  }

  Widget _buildSkeletonCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 14, width: 180, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 12, width: 120, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            Icon(Icons.volunteer_activism_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No donations found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Check back later or try a different area', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

