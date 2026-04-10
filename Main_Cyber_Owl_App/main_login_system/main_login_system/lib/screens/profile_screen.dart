import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_manager.dart';
import '../services/auth_service.dart';
import '../data/countries.dart';
import '../widgets/skeleton_widget.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ProfileScreen({super.key, this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _countryController = TextEditingController();
  final _ageController = TextEditingController();
  final _parentEmailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _userData;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // 1. Try Local First (Instant)
      final localData = await AuthService.getLocalUser();
      if (localData != null) {
        _populateFields(localData);
      }

      // 2. Then Fetch Fresh from Server
      final token = await AuthService.getToken();
      if (token != null) {
        final data = await AuthService.getCurrentUser(token);
        if (mounted) {
          _populateFields(data);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Only show error if we have no data at all
        if (_userData == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading profile: $e')),
          );
        }
      }
    }
  }

  void _populateFields(Map<String, dynamic> data) {
    setState(() {
      _userData = data;
      String rawName = data['name'] ?? '';
      _nameController.text = rawName
          .split(' ')
          .map((str) => str.isNotEmpty
              ? '${str[0].toUpperCase()}${str.substring(1)}'
              : '')
          .join(' ');
      _phoneController.text = data['phone'] ?? '';
      _countryController.text = data['country'] ?? '';
      _ageController.text = data['age'] ?? '';
      _parentEmailController.text = data['parent_email'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadPhoto();
    }
  }

  Future<void> _uploadPhoto() async {
    if (_imageFile == null) return;

    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final result =
            await AuthService.uploadProfilePhoto(token, _imageFile!.path);
        setState(() {
          _userData?['profile_pic'] = result['photo_url'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading photo: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final token = await AuthService.getToken();
      if (token != null) {
        final data = {
          'name': _nameController.text,
          'phone': _phoneController.text,
          'country': _countryController.text,
          'age': _ageController.text,
          'parent_email': _parentEmailController.text,
        };
        await AuthService.updateProfile(token, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, _) {
        final t = themeManager.themeValue;
        final backgroundColor = AppColors.getBackground(t);
        final textColor = AppColors.getTextPrimary(t);
        final secondaryTextColor = AppColors.getTextSecondary(t);
        final surfaceColor = AppColors.getSurface(t);
        final dividerColor = AppColors.getDivider(t);

        return Scaffold(
          backgroundColor: backgroundColor,
          body: _isLoading
              ? _buildSkeletonProfile(backgroundColor)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: widget.onBack ??
                                () => Navigator.of(context).pop(),
                            icon: Icon(FluentIcons.arrow_left_24_regular,
                                color: textColor),
                          ),
                          const SizedBox(width: 8),
                          Text('Profile & Account',
                              style:
                                  AppTextStyles.h1.copyWith(color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Manage your account settings and personal information',
                          style: AppTextStyles.subBody
                              .copyWith(color: secondaryTextColor)),
                      const SizedBox(height: 32),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                children: [
                                  _buildProfileHeader(
                                      textColor: textColor,
                                      secondaryTextColor: secondaryTextColor,
                                      surfaceColor: surfaceColor,
                                      dividerColor: dividerColor,
                                      backgroundColor: backgroundColor),
                                  const SizedBox(height: 24),
                                  _buildProfileForm(
                                      textColor: textColor,
                                      secondaryTextColor: secondaryTextColor,
                                      surfaceColor: surfaceColor,
                                      dividerColor: dividerColor,
                                      backgroundColor: backgroundColor),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildProfileHeader({
    required Color textColor,
    required Color secondaryTextColor,
    required Color surfaceColor,
    required Color dividerColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: CircleAvatar(
                  radius: 43,
                  backgroundColor: backgroundColor,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : (_userData?['profile_pic'] != null
                          ? NetworkImage(() {
                              String url = _userData!['profile_pic'];
                              if (url.startsWith('http')) return url;

                              // Sanitize path (Windows/Linux)
                              String filename = url;
                              if (filename.contains('\\')) {
                                filename = filename.split('\\').last;
                              } else if (filename.contains('/')) {
                                filename = filename.split('/').last;
                              }
                              return '${AuthService.baseUrl.replaceAll('/api', '')}/uploads/$filename';
                            }()) as ImageProvider
                          : null),
                  child: _imageFile == null && _userData?['profile_pic'] == null
                      ? Icon(FluentIcons.person_24_regular,
                          size: 40, color: secondaryTextColor)
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(FluentIcons.camera_24_regular,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_userData?['name'] ?? 'Guest User')
                      .split(' ')
                      .map((str) => str.isNotEmpty
                          ? '${str[0].toUpperCase()}${str.substring(1)}'
                          : '')
                      .join(' '),
                  style: AppTextStyles.h2.copyWith(color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _userData?['email'] ?? '',
                  style:
                      AppTextStyles.subBody.copyWith(color: secondaryTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PRO MEMBER',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileForm({
    required Color textColor,
    required Color secondaryTextColor,
    required Color surfaceColor,
    required Color dividerColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: dividerColor),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Account Information',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildField('Full Name', _nameController,
                      FluentIcons.person_24_regular,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      backgroundColor: backgroundColor),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildField(
                      'Phone', _phoneController, FluentIcons.call_24_regular,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      backgroundColor: backgroundColor, validator: (value) {
                    if (value == null || value.isEmpty) return null; // Optional
                    // Regex: exactly 10 digits
                    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return 'Enter valid 10-digit number';
                    }
                    return null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Country',
                          style: AppTextStyles.subBody.copyWith(
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _countryController.text.isNotEmpty &&
                                kCountries.contains(_countryController.text)
                            ? _countryController.text
                            : null,
                        items: kCountries
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e,
                                      style: AppTextStyles.body
                                          .copyWith(color: textColor)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _countryController.text = val);
                          }
                        },
                        isExpanded: true,
                        decoration: InputDecoration(
                          prefixIcon: Icon(FluentIcons.globe_24_regular,
                              color: secondaryTextColor, size: 20),
                          filled: true,
                          fillColor: backgroundColor.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        dropdownColor: surfaceColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildField(
                      'Age', _ageController, FluentIcons.calendar_24_regular,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      backgroundColor: backgroundColor),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildField('Parent Email', _parentEmailController,
                FluentIcons.mail_24_regular,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                backgroundColor: backgroundColor, validator: (value) {
              if (value == null || value.isEmpty) return null; // Optional
              if (!value.contains('@') || !value.contains('.')) {
                return 'Enter valid email address';
              }
              return null;
            }),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController controller, IconData icon,
      {required Color textColor,
      required Color secondaryTextColor,
      required Color backgroundColor,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.subBody.copyWith(
                fontWeight: FontWeight.w600, color: secondaryTextColor)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: AppTextStyles.body.copyWith(color: textColor),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _saveProfile(),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: secondaryTextColor, size: 20),
            filled: true,
            fillColor: backgroundColor.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorStyle: const TextStyle(color: AppColors.accentRed),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonProfile(Color backgroundColor) {
    final t = themeManager.themeValue;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Skeleton.circle(size: 40),
              SizedBox(width: 8),
              Skeleton.text(width: 200, height: 32),
            ],
          ),
          const SizedBox(height: 8),
          const Skeleton.text(width: 300, height: 16),
          const SizedBox(height: 32),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                  // Skeleton Header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(t),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.getDivider(t)),
                    ),
                    child: const Row(
                      children: [
                        Skeleton.circle(size: 90),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Skeleton.text(width: 150, height: 24),
                              SizedBox(height: 8),
                              Skeleton.text(width: 200, height: 16),
                              SizedBox(height: 12),
                              Skeleton.rect(
                                  width: 100, height: 24, borderRadius: 20),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Skeleton Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(t),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.getDivider(t)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton.text(width: 180, height: 20),
                        SizedBox(height: 24),
                        Row(children: [
                          Expanded(
                              child:
                                  Skeleton.rect(height: 56, borderRadius: 12)),
                          SizedBox(width: 20),
                          Expanded(
                              child:
                                  Skeleton.rect(height: 56, borderRadius: 12))
                        ]),
                        SizedBox(height: 20),
                        Row(children: [
                          Expanded(
                              child:
                                  Skeleton.rect(height: 56, borderRadius: 12)),
                          SizedBox(width: 20),
                          Expanded(
                              child:
                                  Skeleton.rect(height: 56, borderRadius: 12))
                        ]),
                        SizedBox(height: 20),
                        Skeleton.rect(height: 56, borderRadius: 12),
                        SizedBox(height: 32),
                        Skeleton.rect(height: 56, borderRadius: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
