import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../services/cloudinary_service.dart';

class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key});

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<File> _selectedImages = [];
  bool _isLoading = false;
  int _selectedHours = 3;


  // ---------------- IMAGE PICKER ----------------
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70);

    if (images.isNotEmpty) {
      if (images.length > 10) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 images allowed')),
        );
        return;
      }

      setState(() {
        _selectedImages
          ..clear()
          ..addAll(images.map((e) => File(e.path)));
      });
    }
  }

  // ---------------- IMAGE UPLOAD ----------------
  Future<List<String>> uploadImages(List<File> images) async {
  List<String> urls = [];

  for (final img in images) {
    final url = await CloudinaryService.uploadImage(img);
    urls.add(url);
  }

  return urls;
}


  // ---------------- POST DONATION ----------------
  Future<void> _postDonation() async {
    if (_isLoading) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    // VALIDATION
    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required'), backgroundColor: AppColors.dangerRed),
      );
      return;
    }

    if (title.length < 5 || description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide meaningful details'), backgroundColor: AppColors.dangerRed),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // GET USER DISTRICT
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userDistrict = userDoc.data()?['district'];

      final postRef = FirebaseFirestore.instance.collection('posts').doc();

      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await uploadImages(_selectedImages);
      }


      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(Duration(hours: _selectedHours)),
      );

      await postRef.set({
        'userId': user.uid,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'district': userDistrict,
        'images': imageUrls,
        'createdAt': Timestamp.now(),
        'expiresAt': expiresAt,
        'status': 'available',
      });

      if (!mounted) return;

      // RESET UI
      _titleController.clear();
      _descriptionController.clear();
      _selectedImages.clear();

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation posted successfully!'), backgroundColor: AppColors.primaryGreen),
      );
    } catch (e) {
      debugPrint('Error posting donation: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post donation. Try again'), backgroundColor: AppColors.dangerRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Share Donation', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Visuals', Icons.image_outlined),
            const SizedBox(height: 16),
            _buildImagePicker(),
            const SizedBox(height: 32),
            _buildSectionHeader('Details', Icons.description_outlined),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _titleController,
              label: 'Donation Title',
              hint: 'e.g., Fresh extra meals from wedding',
              maxLength: 50,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Mention quantity, food type, and pickup instructions',
              maxLength: 200,
              maxLines: 4,
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Availability', Icons.timer_outlined),
            const SizedBox(height: 16),
            _buildExpiryDropdown(),
            const SizedBox(height: 48),
            _buildPostButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_rounded, size: 32, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text('Add Photos', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                Text('(Max 10 images)', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
        ),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: Colors.grey.shade100,
                          child: Image.file(
                            _selectedImages[index],
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImages.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildExpiryDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedHours,
      decoration: InputDecoration(
        labelText: 'Valid For',
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 1, child: Text('1 Hour')),
        DropdownMenuItem(value: 3, child: Text('3 Hours')),
        DropdownMenuItem(value: 6, child: Text('6 Hours')),
        DropdownMenuItem(value: 12, child: Text('12 Hours')),
      ],
      onChanged: (value) => setState(() => _selectedHours = value!),
    );
  }

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _postDonation,
        child: _isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
            : const Text('Post Donation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
