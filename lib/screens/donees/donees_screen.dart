import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import '../chat/chat_screen.dart';

class DoneesScreen extends StatelessWidget {
  const DoneesScreen({super.key});

  // 🔹 Get user profile by UID
  Future<Map<String, dynamic>?> _getUser(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    return doc.data();
  }

  String formatTime(Timestamp ts) {
    final date = ts.toDate();
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Please log in to see accepted donations',
            style: TextStyle(color: AppColors.softGrey),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Active Connections',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('status', isEqualTo: 'accepted')
            .where('expiresAt', isGreaterThan: Timestamp.now())
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // 🔒 Filter: only donor OR donee can see
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final donorId = data['userId'];
            final acceptedBy = data['acceptedBy'];
            return donorId == currentUser.uid || acceptedBy == currentUser.uid;
          }).toList();

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final isDonor = data['userId'] == currentUser.uid;
              final otherUserId = isDonor ? data['acceptedBy'] : data['userId'];

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUser(otherUserId),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  final otherUser = userSnapshot.data!;
                  final otherName = otherUser['name'] ?? 'Kind Soul';
                  final otherDistrict = otherUser['district'] ?? 'Unknown';

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha:0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildRoleBadge(isDonor),
                              Text(
                                formatTime(data['acceptedAt'] ?? Timestamp.now()),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.softGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            data['title'] ?? 'Donation Item',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            data['description'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const Divider(height: 24, thickness: 0.8),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryGreen.withValues(alpha:0.1),
                                child: Text(
                                  otherName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isDonor ? 'Receiver: $otherName' : 'Donor: $otherName',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      otherDistrict,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.softGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: AppColors.primaryGreen.withValues(alpha:0.8),
                                  size: 22,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatScreen(
                                        otherUserId: otherUserId,
                                        otherUserName: otherName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRoleBadge(bool isDonor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDonor
            ? AppColors.accentOrange.withValues(alpha:0.1)
            : Colors.blue.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isDonor ? 'DONOR' : 'RECIPIENT',
        style: TextStyle(
          color: isDonor ? AppColors.accentOrange : Colors.blue.shade700,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.handshake_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No connections yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accepted donations will appear here',
            style: TextStyle(color: AppColors.softGrey),
          ),
        ],
      ),
    );
  }
}

