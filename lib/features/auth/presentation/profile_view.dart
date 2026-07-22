import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/flash_message.dart';
import '../../../../core/widgets/forge_skeleton.dart';
import '../../../../core/widgets/forge_spinner.dart';
import '../controllers/auth_controller.dart';
import '../controllers/profile_controller.dart';
import '../models/user_profile_model.dart';

class ProfileView extends ConsumerStatefulWidget {
  final bool isActive;
  const ProfileView({super.key, required this.isActive});

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _injuriesCtrl;

  String? _fitnessGoal;
  String? _experienceLevel;
  bool _isMetric = true;

  bool _formInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _heightCtrl = TextEditingController();
    _injuriesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _injuriesCtrl.dispose();
    super.dispose();
  }

  void _populateForm(UserProfileModel profile) {
    _nameCtrl.text = profile.name;
    _weightCtrl.text = profile.weightKg?.toStringAsFixed(1) ?? '';
    _heightCtrl.text = profile.heightCm?.toStringAsFixed(1) ?? '';
    _injuriesCtrl.text = profile.injuriesOrLimitations ?? '';
    _fitnessGoal = profile.fitnessGoal;
    _experienceLevel = profile.experienceLevel;
    _isMetric = profile.preferredUnit == 'metric';
    _formInitialized = true;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.tryParse(_weightCtrl.text.trim());
    final height = double.tryParse(_heightCtrl.text.trim());

    final success = await ref.read(profileControllerProvider.notifier).saveProfile(
          name: _nameCtrl.text.trim(),
          preferredUnit: _isMetric ? 'metric' : 'imperial',
          weightKg: weight,
          heightCm: height,
          fitnessGoal: _fitnessGoal,
          experienceLevel: _experienceLevel,
          injuriesOrLimitations: _injuriesCtrl.text.trim().isEmpty
              ? null
              : _injuriesCtrl.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      context.showSuccessFlash('Profile updated successfully!');
    } else {
      final err = ref.read(profileControllerProvider).saveErrorMessage;
      context.showErrorFlash(err ?? 'Failed to update profile.');
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || name.trim().isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String _memberSince(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return 'Member since ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);

    // Populate form once when profile first loads
    if (!_formInitialized && state.profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _populateForm(state.profile!);
          });
        }
      });
    }

    if (state.isLoading) return _buildSkeleton();

    if (state.profile == null) {
      return _buildError(
        state.errorMessage ?? 'Failed to load profile.',
        onRetry: () =>
            ref.read(profileControllerProvider.notifier).fetchProfile(),
      );
    }

    final profile = state.profile!;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(profile),
            const SizedBox(height: 32),
            _buildSectionLabel('Personal Info'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameCtrl,
              label: 'Full Name',
              icon: Icons.person_outline_rounded,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name cannot be empty';
                if (v.trim().length > 100) return 'Name too long (max 100 chars)';
                return null;
              },
            ),
            const SizedBox(height: 32),
            _buildSectionLabel('Body Metrics'),
            const SizedBox(height: 12),
            _buildUnitToggle(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildNumberField(
                    controller: _weightCtrl,
                    label: _isMetric ? 'Weight (kg)' : 'Weight (lbs)',
                    icon: Icons.monitor_weight_outlined,
                    max: 500,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNumberField(
                    controller: _heightCtrl,
                    label: _isMetric ? 'Height (cm)' : 'Height (in)',
                    icon: Icons.height_rounded,
                    max: 300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionLabel('Fitness Profile'),
            const SizedBox(height: 12),
            _buildDropdown(
              label: 'Fitness Goal',
              icon: Icons.flag_outlined,
              value: _fitnessGoal,
              items: fitnessGoalOptions,
              onChanged: (v) => setState(() => _fitnessGoal = v),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Experience Level',
              icon: Icons.bar_chart_rounded,
              value: _experienceLevel,
              items: experienceLevelOptions,
              onChanged: (v) => setState(() => _experienceLevel = v),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _injuriesCtrl,
              label: 'Injuries / Limitations',
              icon: Icons.medical_services_outlined,
              maxLines: 3,
              isRequired: false,
              validator: (v) {
                if (v != null && v.length > 500) {
                  return 'Max 500 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            _buildSaveButton(state.isSaving),
            const SizedBox(height: 16),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(UserProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Initials Avatar
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _initials(profile.name),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _memberSince(profile.createdAt),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

  // ── Section Label ────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.primary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  // ── Unit Toggle ──────────────────────────────────────────────────────────────

  Widget _buildUnitToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(Icons.straighten_rounded,
              color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isMetric ? 'Metric (kg / cm)' : 'Imperial (lbs / in)',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: _isMetric,
            onChanged: (v) => setState(() => _isMetric = v),
            activeColor: AppTheme.primary,
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.25),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            inactiveThumbColor: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }

  // ── Text Field ────────────────────────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool isRequired = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  // ── Number Field ──────────────────────────────────────────────────────────────

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required double max,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        final val = double.tryParse(v.trim());
        if (val == null) return 'Invalid number';
        if (val < 0 || val > max) return 'Out of range (0–$max)';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
    );
  }

  // ── Dropdown ──────────────────────────────────────────────────────────────────

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String? value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: AppTheme.cardBg,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      icon: const Icon(Icons.expand_more_rounded,
          color: AppTheme.textSecondary, size: 20),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
      items: [
        DropdownMenuItem<String>(
          value: null,
          child: Text('Not set',
              style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7))),
        ),
        ...items.entries.map((e) => DropdownMenuItem<String>(
              value: e.key,
              child: Text(e.value),
            )),
      ],
      onChanged: onChanged,
    );
  }

  // ── Save Button ───────────────────────────────────────────────────────────────

  Widget _buildSaveButton(bool isSaving) {
    return ElevatedButton(
      onPressed: isSaving ? null : _onSave,
      child: isSaving
          ? const SizedBox(
              height: 22,
              width: 22,
              child: ForgeSpinner(size: 22),
            )
          : const Text('Save Changes'),
    );
  }

  // ── Logout Button ──────────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.error,
        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppTheme.error.withValues(alpha: 0.06),
      ),
      icon: const Icon(Icons.logout_rounded, size: 20),
      label: const Text(
        'Log Out',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Log Out',
                style: TextStyle(color: AppTheme.textPrimary)),
            content: const Text(
              'Are you sure you want to log out?',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(authControllerProvider.notifier).logout();
                },
                child: const Text('Log Out',
                    style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Skeleton Loading ───────────────────────────────────────────────────────────

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const ForgeSkeleton(
                    height: 72, width: 72, borderRadius: BorderRadius.all(Radius.circular(36))),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ForgeSkeleton(height: 20, width: 140),
                      SizedBox(height: 8),
                      ForgeSkeleton(height: 14, width: 180),
                      SizedBox(height: 10),
                      ForgeSkeleton(height: 24, width: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(
            6,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ForgeSkeleton(
                  height: 52, width: double.infinity, borderRadius: const BorderRadius.all(Radius.circular(12))),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────────────────────

  Widget _buildError(String message, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load profile',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
              label: const Text('Retry',
                  style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
