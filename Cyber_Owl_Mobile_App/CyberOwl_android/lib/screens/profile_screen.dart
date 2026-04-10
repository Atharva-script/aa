import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Profile Fields
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  late TextEditingController _countryController;
  String? _email;

  // Schedule Fields
  bool _scheduleLoaded = false;
  String _frequency = 'daily';
  TimeOfDay _rotationTime = const TimeOfDay(hour: 0, minute: 0);
  int _dayOfWeek = 0; // 0=Monday

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _ageController = TextEditingController();
    _countryController = TextEditingController();

    // Load data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    // 1. Load Profile
    final profileData = await provider.getProfile();
    if (profileData != null && profileData['user'] != null) {
      final user = profileData['user'];
      _email = user['email'];
      _nameController.text = user['name'] ?? '';
      _phoneController.text = user['phone'] ?? '';
      _ageController.text = (user['age'] ?? '').toString();
      _countryController.text = user['country'] ?? '';
    }

    // 2. Load Schedule
    final scheduleData = await provider.getSecretCodeSchedule();
    if (scheduleData != null) {
      _frequency = scheduleData['frequency'] ?? 'daily';
      final timeStr = scheduleData['rotation_time'] ?? '00:00';
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        _rotationTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0);
      }
      _dayOfWeek = scheduleData['day_of_week'] ?? 0;
      _scheduleLoaded = true;
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Uploading image...')),
        );
      }

      if (!mounted) return;

      final provider = Provider.of<AppProvider>(context, listen: false);
      final success = await provider.uploadProfilePhoto(file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Profile photo updated' : 'Upload failed'),
            backgroundColor: success ? AppColors.success : AppColors.danger,
          ),
        );
        if (success) _loadData(); // Reload to get new URL
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'country': _countryController.text.trim(),
      };

      final result = await provider.updateProfile(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['success']
                ? 'Profile updated successfully'
                : 'Failed: ${result['message']}'),
            backgroundColor:
                result['success'] ? AppColors.success : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<AppProvider>(context, listen: false);

    try {
      final timeStr =
          '${_rotationTime.hour.toString().padLeft(2, '0')}:${_rotationTime.minute.toString().padLeft(2, '0')}';

      final data = {
        'frequency': _frequency,
        'rotation_time': timeStr,
        'day_of_week': _dayOfWeek,
        'is_active': true
      };

      final success = await provider.updateSecretCodeSchedule(data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Schedule updated successfully'
                : 'Failed to update schedule'),
            backgroundColor: success ? AppColors.success : AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.backgroundDark, AppColors.surfaceDark]
                : [AppColors.backgroundLight, Colors.white],
          ),
        ),
        child: _isLoading && _email == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // 1. Profile Header with Avatar
                        _buildProfileHeader(isDark),
                        const SizedBox(height: 32),

                        // 2. Personal Info Card
                        _buildSectionTitle('Personal Information'),
                        const SizedBox(height: 12),
                        _buildPersonalInfoCard(isDark),
                        const SizedBox(height: 24),

                        // 3. Security / Schedule Card
                        _buildSectionTitle('Security & Automation'),
                        const SizedBox(height: 12),
                        _buildSecurityCard(isDark),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryPurple, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: ClipOval(
                child: Consumer<AppProvider>(
                  builder: (context, provider, child) {
                    final photoUrl = provider.fullUserPhotoUrl;
                    return (photoUrl != null && photoUrl.isNotEmpty)
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(FluentIcons.person_24_regular,
                                    size: 60, color: Colors.grey),
                          )
                        : const Icon(FluentIcons.person_24_regular,
                            size: 60, color: Colors.grey);
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickAndUploadImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                      )
                    ],
                  ),
                  child: const Icon(FluentIcons.camera_24_regular,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _nameController.text.isNotEmpty
              ? _nameController.text
              : 'User Profile',
          style: AppTextStyles.h2,
        ),
        const SizedBox(height: 4),
        Text(
          _email ?? 'Loading...',
          style: AppTextStyles.body.copyWith(
            color: AppColors.getTextSecondary(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.getDivider(isDark).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: FluentIcons.person_24_regular,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: FluentIcons.phone_24_regular,
            isDark: isDark,
            inputType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  icon: FluentIcons.calendar_24_regular,
                  isDark: isDark,
                  inputType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTextField(
                  controller: _countryController,
                  label: 'Country',
                  icon: FluentIcons.map_24_regular,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(bool isDark) {
    if (!_scheduleLoaded) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getSurface(isDark).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.getDivider(isDark).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(FluentIcons.shield_lock_24_regular,
                    color: AppColors.warning, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Rotation',
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      'Automatically change secret code',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.getTextSecondary(isDark)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            decoration: _inputDecoration('Frequency', isDark, null),
            dropdownColor: AppColors.getSurface(isDark),
            style: TextStyle(
                color: AppColors.getTextPrimary(isDark), fontSize: 14),
            items: const [
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
            ],
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          if (_frequency == 'weekly') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              decoration: _inputDecoration('Day of Week', isDark, null),
              dropdownColor: AppColors.getSurface(isDark),
              style: TextStyle(
                  color: AppColors.getTextPrimary(isDark), fontSize: 14),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Monday')),
                DropdownMenuItem(value: 1, child: Text('Tuesday')),
                DropdownMenuItem(value: 2, child: Text('Wednesday')),
                DropdownMenuItem(value: 3, child: Text('Thursday')),
                DropdownMenuItem(value: 4, child: Text('Friday')),
                DropdownMenuItem(value: 5, child: Text('Saturday')),
                DropdownMenuItem(value: 6, child: Text('Sunday')),
              ],
              onChanged: (v) => setState(() => _dayOfWeek = v!),
            ),
          ],
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _rotationTime,
              );
              if (time != null) {
                setState(() => _rotationTime = time);
              }
            },
            child: InputDecorator(
              decoration: _inputDecoration(
                  'Rotation Time', isDark, FluentIcons.clock_24_regular),
              child: Text(
                _rotationTime.format(context),
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _saveSchedule,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryPurple),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Update Schedule'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      style: TextStyle(color: AppColors.getTextPrimary(isDark)),
      decoration: _inputDecoration(label, isDark, icon),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  InputDecoration _inputDecoration(String label, bool isDark, IconData? icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.getTextSecondary(isDark)),
      prefixIcon: icon != null
          ? Icon(icon, color: AppColors.primaryPurple.withValues(alpha: 0.7))
          : null,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: AppColors.getDivider(isDark).withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
      ),
      filled: true,
      fillColor: isDark
          ? Colors.black.withValues(alpha: 0.2)
          : Colors.grey.withValues(alpha: 0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
