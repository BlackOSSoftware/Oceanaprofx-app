import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/trading_service.dart';
import '../../ui/country_dial_codes.dart';
import '../../ui/icons/oc_icons.dart';
import '../../ui/theme/oceana_colors.dart';

/// Edit Profile � clean sections, icons, country-code phone picker.
class OceanaProfileEditPage extends StatefulWidget {
  const OceanaProfileEditPage({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OceanaProfileEditPage()),
    );
  }

  @override
  State<OceanaProfileEditPage> createState() => _OceanaProfileEditPageState();
}

class _OceanaProfileEditPageState extends State<OceanaProfileEditPage> {
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _country = TextEditingController();
  final _pincode = TextEditingController();

  CountryDial _dial = CountryDialCodes.defaultIndia;
  String? _gender;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _name = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _dob.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _country.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await tradingService.fetchUserProfile(force: true);
      if (!mounted) return;
      _name = '${p['name'] ?? ''}'.trim();
      _email = '${p['email'] ?? ''}'.trim();
      if (_email.isEmpty) {
        _email = tradingService.userPortal?.email ?? '';
      }
      final split = CountryDialCodes.splitPhone('${p['phone'] ?? ''}');
      _dial = split.$1;
      _phone.text = split.$2;
      final dob = '${p['date_of_birth'] ?? ''}';
      _dob.text = dob.length >= 10 ? dob.substring(0, 10) : dob;
      final g = '${p['gender'] ?? ''}'.toUpperCase();
      _gender = (g == 'MALE' || g == 'FEMALE') ? g : null;
      _line1.text = '${p['address_line_1'] ?? ''}';
      _line2.text = '${p['address_line_2'] ?? ''}';
      _city.text = '${p['city'] ?? ''}';
      _state.text = '${p['state'] ?? ''}';
      _country.text = '${p['country'] ?? ''}';
      _pincode.text = '${p['pincode'] ?? ''}';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e'.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_dob.text) ?? DateTime(1995, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: OcColors.primary,
            onPrimary: Colors.white,
            surface: OcColors.surface,
            onSurface: OcColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final m = picked.month.toString().padLeft(2, '0');
    final d = picked.day.toString().padLeft(2, '0');
    setState(() => _dob.text = '${picked.year}-$m-$d');
  }

  Future<void> _pickCountryCode() async {
    final selected = await showModalBottomSheet<CountryDial>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OcColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => _CountryCodeSheet(current: _dial),
    );
    if (selected == null || !mounted) return;
    setState(() => _dial = selected);
  }

  String get _fullPhone {
    final n = _phone.text.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (n.isEmpty) return '';
    if (n.startsWith('+')) return n;
    return '${_dial.dial}$n';
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final phone = _fullPhone;
      final body = <String, dynamic>{
        'address_line_1': _line1.text.trim(),
        'address_line_2': _line2.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'country': _country.text.trim(),
        'pincode': _pincode.text.trim(),
      };
      // Always send phone (empty clears it server-side).
      body['phone'] = phone;
      final dob = _dob.text.trim();
      if (dob.isNotEmpty) body['date_of_birth'] = dob;
      if (_gender != null) body['gender'] = _gender;
      await tradingService.updateUserProfile(body);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
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

  String get _initials {
    final parts = _name.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    if (parts.isEmpty) return 'U';
    final list = parts.take(2).map((e) => e[0].toUpperCase()).join();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OcColors.bg,
      appBar: AppBar(
        backgroundColor: OcColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(OcIcons.chevronLeft, color: OcColors.text),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: OcColors.text,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      _headerCard(),
                      const SizedBox(height: 16),
                      _sectionTitle('Contact'),
                      const SizedBox(height: 8),
                      _phoneRow(),
                      const SizedBox(height: 16),
                      _sectionTitle('Personal'),
                      const SizedBox(height: 8),
                      _dobField(),
                      const SizedBox(height: 12),
                      _genderBlock(),
                      const SizedBox(height: 16),
                      _sectionTitle('Address'),
                      const SizedBox(height: 8),
                      _iconField(
                        controller: _line1,
                        label: 'Address line 1',
                        icon: OcIcons.home,
                      ),
                      const SizedBox(height: 12),
                      _iconField(
                        controller: _line2,
                        label: 'Address line 2',
                        icon: OcIcons.mapPin,
                      ),
                      const SizedBox(height: 12),
                      _iconField(
                        controller: _city,
                        label: 'City',
                        icon: OcIcons.building2,
                      ),
                      const SizedBox(height: 12),
                      _iconField(
                        controller: _state,
                        label: 'State / Province',
                        icon: OcIcons.map,
                      ),
                      const SizedBox(height: 12),
                      _iconField(
                        controller: _country,
                        label: 'Country',
                        icon: OcIcons.globe,
                      ),
                      const SizedBox(height: 12),
                      _iconField(
                        controller: _pincode,
                        label: 'Pincode / ZIP',
                        icon: OcIcons.hash,
                        keyboard: TextInputType.number,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: OcColors.withdrawBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: OcColors.loss.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(OcIcons.info, size: 18, color: OcColors.loss),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: OcColors.loss,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        'Changes apply instantly after save.',
                        style: TextStyle(
                          color: OcColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: OcColors.surface,
                      border: Border(
                        top: BorderSide(color: OcColors.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _busy ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: OcColors.text,
                              side: BorderSide(color: OcColors.borderStrong),
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: FilledButton(
                            onPressed: _busy ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: OcColors.primary,
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              _busy ? 'Saving�' : 'Save changes',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
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

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: OcColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: OcColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OcColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OcColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: OcColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              _initials,
              style: TextStyle(
                color: OcColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isEmpty ? 'Your name' : _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: OcColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                _metaLine(OcIcons.mail, _email.isEmpty ? '�' : _email),
                const SizedBox(height: 4),
                Text(
                  'Name & email are managed by your account',
                  style: TextStyle(
                    color: OcColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: OcColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: OcColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _phoneRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: OcColors.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _pickCountryCode,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: OcColors.borderStrong),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_dial.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text(
                    _dial.dial,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: OcColors.text,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    OcIcons.chevronDown,
                    size: 16,
                    color: OcColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _iconField(
            controller: _phone,
            label: 'Phone number',
            icon: OcIcons.phone,
            keyboard: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dobField() {
    return Material(
      color: OcColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _pickDob,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: _deco('Date of birth', prefix: OcIcons.calendar),
          child: Text(
            _dob.text.isEmpty ? 'Select date' : _dob.text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: _dob.text.isEmpty ? OcColors.placeholder : OcColors.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _genderBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(OcIcons.user, size: 14, color: OcColors.primary),
              const SizedBox(width: 6),
              Text(
                'Gender',
                style: TextStyle(
                  color: OcColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _genderBtn('MALE', 'Male')),
            const SizedBox(width: 10),
            Expanded(child: _genderBtn('FEMALE', 'Female')),
          ],
        ),
      ],
    );
  }

  Widget _genderBtn(String value, String label) {
    final selected = _gender == value;
    return Material(
      color: selected ? OcColors.primary : OcColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _gender = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? OcColors.primary : OcColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: selected ? Colors.white : OcColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label, {IconData? prefix}) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: OcColors.surface,
        prefixIcon: prefix == null
            ? null
            : Icon(prefix, size: 18, color: OcColors.primary),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        labelStyle: TextStyle(
          color: OcColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: OcColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: OcColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: OcColors.primary, width: 1.4),
        ),
      );

  Widget _iconField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: OcColors.text,
      ),
      decoration: _deco(label, prefix: icon),
    );
  }
}

/* ---------------- country code sheet ---------------- */

class _CountryCodeSheet extends StatefulWidget {
  const _CountryCodeSheet({required this.current});
  final CountryDial current;

  @override
  State<_CountryCodeSheet> createState() => _CountryCodeSheetState();
}

class _CountryCodeSheetState extends State<_CountryCodeSheet> {
  final _q = TextEditingController();
  late List<CountryDial> _rows;

  @override
  void initState() {
    super.initState();
    _rows = CountryDialCodes.all;
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: OcColors.borderStrong,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Country code',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: OcColors.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(OcIcons.x, color: OcColors.textSecondary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _q,
              onChanged: (v) =>
                  setState(() => _rows = CountryDialCodes.search(v)),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: OcColors.text,
              ),
              decoration: InputDecoration(
                hintText: 'Search country or code',
                hintStyle: TextStyle(color: OcColors.placeholder),
                prefixIcon: Icon(
                  OcIcons.search,
                  size: 18,
                  color: OcColors.textMuted,
                ),
                filled: true,
                fillColor: OcColors.bg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: OcColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: OcColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: OcColors.primary, width: 1.3),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _rows.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: OcColors.border,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, i) {
                final c = _rows[i];
                final on = c.iso2 == widget.current.iso2 &&
                    c.dial == widget.current.dial;
                return ListTile(
                  onTap: () => Navigator.pop(context, c),
                  leading: Text(c.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(
                    c.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: OcColors.text,
                    ),
                  ),
                  subtitle: Text(
                    c.iso2,
                    style: TextStyle(
                      color: OcColors.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        c.dial,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: OcColors.primary,
                          fontSize: 14,
                        ),
                      ),
                      if (on) ...[
                        const SizedBox(width: 8),
                        Icon(
                          OcIcons.checkCircle2,
                          size: 18,
                          color: OcColors.primary,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
