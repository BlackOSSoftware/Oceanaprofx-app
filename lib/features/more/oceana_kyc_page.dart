import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/trading_service.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// KYC identity check — Trade-Portal document upload flow.
class OceanaKycPage extends StatefulWidget {
  const OceanaKycPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OceanaKycPage()),
    );
  }

  @override
  State<OceanaKycPage> createState() => _OceanaKycPageState();
}

class _OceanaKycPageState extends State<OceanaKycPage> {
  String _docType = 'PASSPORT';
  String? _frontPath;
  String? _backPath;
  String? _selfiePath;
  String? _frontUrl;
  String? _backUrl;
  String? _selfieUrl;
  String _status = 'NOT_STARTED';
  String? _rejection;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final kyc = await tradingService.fetchMyKyc(force: true);
      if (!mounted) return;
      final status = '${kyc['status'] ?? 'NOT_STARTED'}'.toUpperCase();
      final docs = kyc['documents'];
      String? urlOf(String key) {
        if (docs is! Map) return null;
        final row = docs[key];
        if (row is! Map) return null;
        final u = '${row['image_url'] ?? ''}'.trim();
        return u.isEmpty ? null : u;
      }

      setState(() {
        _status = status;
        _rejection = '${kyc['rejectionReason'] ?? ''}'.trim();
        if (_rejection!.isEmpty) _rejection = null;
        _frontUrl = urlOf('front');
        _backUrl = urlOf('back');
        _selfieUrl = urlOf('selfie');
        final dt = '${kyc['documentType'] ?? ''}'.trim();
        if (dt.isNotEmpty) _docType = dt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pick(String slot) async {
    if (_status == 'PENDING' || _status == 'VERIFIED') return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (file == null) return;
    final size = await File(file.path).length();
    if (size > 5 * 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be under 5 MB')),
      );
      return;
    }
    setState(() {
      switch (slot) {
        case 'front':
          _frontPath = file.path;
          _frontUrl = null;
        case 'back':
          _backPath = file.path;
          _backUrl = null;
        case 'selfie':
          _selfiePath = file.path;
          _selfieUrl = null;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_frontPath == null && _frontUrl == null) {
      setState(() => _error = 'Front image and selfie are required');
      return;
    }
    if (_selfiePath == null && _selfieUrl == null) {
      setState(() => _error = 'Front image and selfie are required');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Future<Map<String, dynamic>> up(String? path, String? existingUrl, String folder) async {
        if (path != null) {
          final r = await tradingService.uploadKycImage(path, folder: folder);
          return {
            'image_url': r.imageUrl,
            'image_public_id': r.publicId,
          };
        }
        // Resubmit with existing cloud URL — need public_id; re-upload if only URL.
        if (existingUrl != null && existingUrl.isNotEmpty) {
          // Prefer fresh pick; if only remote URL from prior reject, ask re-pick.
          throw ApiException('Please re-select $folder image');
        }
        throw ApiException('Missing $folder image');
      }

      final front = await up(_frontPath, _frontUrl, 'kyc/front');
      final selfie = await up(_selfiePath, _selfieUrl, 'kyc/selfie');
      Map<String, dynamic>? back;
      if (_backPath != null) {
        back = await up(_backPath, null, 'kyc/back');
      }

      await tradingService.submitKyc(
        documentType: _docType,
        front: front,
        selfie: selfie,
        back: back,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'KYC submitted — verification is now pending',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnly = _status == 'PENDING' || _status == 'VERIFIED';
    return Scaffold(
      backgroundColor: OcColors.surface,
      appBar: AppBar(
        backgroundColor: OcColors.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.arrowBack, color: OcColors.text),
        ),
        title: const Text(
          'KYC identity check',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      if (_status == 'VERIFIED')
                        _banner(
                          'Identity verified',
                          'Your verification is complete.',
                          OcColors.depositBg,
                          OcColors.depositFg,
                        ),
                      if (_status == 'PENDING')
                        _banner(
                          'Verification in progress',
                          'We are reviewing your documents.',
                          const Color(0xFFFFF8E1),
                          const Color(0xFFF9A825),
                        ),
                      if (_status == 'REJECTED')
                        _banner(
                          'Rejected',
                          _rejection ??
                              'Your documents were rejected. Please resubmit.',
                          OcColors.withdrawBg,
                          OcColors.withdrawFg,
                        ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Document type',
                          labelStyle: const TextStyle(
                            color: OcColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _docType,
                            isExpanded: true,
                            onChanged: readOnly
                                ? null
                                : (v) {
                                    if (v != null) setState(() => _docType = v);
                                  },
                            items: const [
                              DropdownMenuItem(
                                value: 'PASSPORT',
                                child: Text('Passport'),
                              ),
                              DropdownMenuItem(
                                value: 'NIC',
                                child: Text('National ID'),
                              ),
                              DropdownMenuItem(
                                value: 'DRIVING_LICENSE',
                                child: Text('Driving License'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Upload photos',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'JPG/PNG up to 5 MB · Front & Selfie required',
                        style: TextStyle(
                          color: OcColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _uploadTile(
                              label: 'Front',
                              path: _frontPath,
                              url: _frontUrl,
                              onTap: () => _pick('front'),
                              enabled: !readOnly,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _uploadTile(
                              label: 'Back',
                              path: _backPath,
                              url: _backUrl,
                              onTap: () => _pick('back'),
                              enabled: !readOnly,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _uploadTile(
                              label: 'Selfie',
                              path: _selfiePath,
                              url: _selfieUrl,
                              onTap: () => _pick('selfie'),
                              enabled: !readOnly,
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: OcColors.loss,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!readOnly)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: OcColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _busy ? 'Submitting…' : 'Submit verification',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _banner(String title, String body, Color bg, Color fg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w800, color: fg, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(color: fg.withValues(alpha: 0.9), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _uploadTile({
    required String label,
    required String? path,
    required String? url,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    final has = (path != null && path.isNotEmpty) ||
        (url != null && url.isNotEmpty);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OcColors.borderStrong),
          color: OcColors.bg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null)
              Image.file(File(path), fit: BoxFit.cover)
            else if (url != null)
              Image.network(url, fit: BoxFit.cover)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    OcIcons.plus,
                    color: OcColors.primary,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            if (has)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
