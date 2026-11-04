import 'package:flutter/material.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// Change Master Password dialog — SS layout, Oceana brand.
Future<void> showOceanaChangePasswordDialog(
  BuildContext context, {
  required String accountNumber,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _ChangePasswordDialog(accountNumber: accountNumber),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.accountNumber});
  final String accountNumber;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _showNew = false;
  bool _showConfirm = false;
  bool _busy = false;

  @override
  void dispose() {
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _currentPassword {
    final n = widget.accountNumber.trim();
    for (final a in tradingService.fpAccounts) {
      if (a.accountNumber.trim() == n && a.password.isNotEmpty) {
        return a.password;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final next = _new.text.trim();
    final conf = _confirm.text.trim();
    if (next.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters')),
      );
      return;
    }
    if (next != conf) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    final current = _currentPassword;
    if (current == null || current.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved password missing — re-login and try again'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await tradingService.changePassword(
        kind: 'master',
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Master password changed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: OcColors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change Master Password',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: OcColors.text,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Account: ${widget.accountNumber}',
              style: TextStyle(
                color: OcColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            _field(
              controller: _new,
              hint: 'New Password',
              obscure: !_showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: 12),
            _field(
              controller: _confirm,
              hint: 'Confirm Password',
              obscure: !_showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: OcColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _busy ? 'Changing…' : 'Change Password',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OcColors.primary,
                  side: BorderSide(color: OcColors.primary, width: 1.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: OcColors.placeholder, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF5F5F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? OcIcons.eye : OcIcons.eyeOff,
            size: 20,
            color: OcColors.text,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OcColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OcColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: OcColors.primary, width: 1.4),
        ),
      ),
    );
  }
}
