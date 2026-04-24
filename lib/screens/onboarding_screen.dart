import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.storage,
    this.isFirstRun = false,
  });

  final StorageService storage;
  final bool isFirstRun;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ageCtl = TextEditingController();
  final _heightCtl = TextEditingController();
  final _weightCtl = TextEditingController();
  Gender? _gender;

  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    final existing = widget.storage.userProfile;
    _profile = existing;
    if (existing != null) {
      if (existing.ageYears != null) {
        _ageCtl.text = existing.ageYears.toString();
      }
      if (existing.heightCm != null) {
        _heightCtl.text = existing.heightCm!.toStringAsFixed(0);
      }
      if (existing.weightKg != null) {
        _weightCtl.text = existing.weightKg!.toStringAsFixed(0);
      }
      _gender = existing.gender;
    }
  }

  @override
  void dispose() {
    _ageCtl.dispose();
    _heightCtl.dispose();
    _weightCtl.dispose();
    super.dispose();
  }

  Future<void> _save({required bool continueToHome}) async {
    final existing = _profile ?? await widget.storage.ensureUserProfile();
    final updated = existing.copyWith(
      ageYears: int.tryParse(_ageCtl.text.trim()),
      heightCm: double.tryParse(_heightCtl.text.trim()),
      weightKg: double.tryParse(_weightCtl.text.trim()),
      gender: _gender,
    );
    await widget.storage.saveUserProfile(updated);
    if (!mounted) return;
    if (continueToHome) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(storage: widget.storage),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile ?? widget.storage.userProfile;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstRun ? 'About you' : 'Profile'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _IdCard(userId: profile?.userId ?? '…'),
            const SizedBox(height: 24),
            Text(
              'Optional demographics',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'These fields are optional. They help researchers interpret '
              'the sensor data but you can leave any of them empty.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageCtl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Age (years)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _heightCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: const InputDecoration(
                labelText: 'Height (cm)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(5),
              ],
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Gender?>(
              initialValue: _gender,
              decoration: const InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<Gender?>(
                  value: null,
                  child: Text('—'),
                ),
                for (final g in Gender.values)
                  DropdownMenuItem(value: g, child: Text(g.label)),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => _save(continueToHome: widget.isFirstRun),
              child: Text(widget.isFirstRun ? 'Continue' : 'Save'),
            ),
            if (widget.isFirstRun)
              TextButton(
                onPressed: () => _save(continueToHome: true),
                child: const Text('Skip for now'),
              ),
          ],
        ),
      ),
    );
  }
}

class _IdCard extends StatelessWidget {
  const _IdCard({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fingerprint,
            color: theme.colorScheme.onPrimaryContainer,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your anonymous ID',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userId,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
