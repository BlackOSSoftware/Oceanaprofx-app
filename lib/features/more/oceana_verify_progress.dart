/// Profile + KYC completion % — same idea as Trade-Portal verify checklist.
///
/// 5 equal steps (20% each):
/// 1. Email verified
/// 2. Phone added
/// 3. Personal info (DOB + gender)
/// 4. Address (line1 + city + country)
/// 5. KYC — only VERIFIED counts as complete for "fully verified".
///    PENDING still advances progress % (docs submitted).
class OceanaVerifyProgress {
  const OceanaVerifyProgress({
    required this.emailDone,
    required this.phoneDone,
    required this.personalDone,
    required this.addressDone,
    required this.kycDone,
    required this.kycStatus,
    required this.percent,
  });

  final bool emailDone;
  final bool phoneDone;
  final bool personalDone;
  final bool addressDone;

  /// True only when KYC is VERIFIED (not pending/rejected).
  final bool kycDone;
  final String kycStatus;
  final int percent;

  bool get kycPending => kycStatus == 'PENDING';
  bool get kycRejected => kycStatus == 'REJECTED';
  bool get kycVerified => kycStatus == 'VERIFIED';

  /// Progress bar: submitted (pending) or verified both count.
  bool get kycSubmitted => kycPending || kycVerified;

  bool get fullyVerified =>
      emailDone && phoneDone && personalDone && addressDone && kycVerified;

  int get doneCount =>
      [emailDone, phoneDone, personalDone, addressDone, kycSubmitted]
          .where((e) => e)
          .length;

  static OceanaVerifyProgress from({
    required Map<String, dynamic>? profile,
    required Map<String, dynamic>? kyc,
    bool emailVerifiedHint = false,
  }) {
    final p = profile ?? const <String, dynamic>{};
    final k = kyc ?? const <String, dynamic>{};

    // Hint covers sticky login / portal flag while /me is loading or incomplete.
    final emailDone =
        emailVerifiedHint || _isTruthy(p['isMailVerified']);
    final phoneDone = '${p['phone'] ?? ''}'.trim().isNotEmpty;

    final dob = '${p['date_of_birth'] ?? ''}'.trim();
    final gender = '${p['gender'] ?? ''}'.trim();
    final personalDone = dob.isNotEmpty && gender.isNotEmpty;

    final line1 = '${p['address_line_1'] ?? ''}'.trim();
    final city = '${p['city'] ?? ''}'.trim();
    final country = '${p['country'] ?? ''}'.trim();
    final addressDone =
        line1.isNotEmpty && city.isNotEmpty && country.isNotEmpty;

    // Prefer live KYC document status over cached user.kycStatus.
    var kycStatus = '${k['status'] ?? ''}'.trim().toUpperCase();
    if (kycStatus.isEmpty || kycStatus == 'NULL' || kycStatus == 'NOT_STARTED') {
      final fromUser = '${p['kycStatus'] ?? ''}'.trim().toUpperCase();
      if (fromUser.isNotEmpty) kycStatus = fromUser;
    }
    if (kycStatus.isEmpty) kycStatus = 'NOT_STARTED';

    final kycVerified = kycStatus == 'VERIFIED';
    final kycPending = kycStatus == 'PENDING';
    final kycSubmitted = kycVerified || kycPending;

    final steps = [
      emailDone,
      phoneDone,
      personalDone,
      addressDone,
      kycSubmitted,
    ];
    final percent =
        ((steps.where((e) => e).length / steps.length) * 100).round();

    return OceanaVerifyProgress(
      emailDone: emailDone,
      phoneDone: phoneDone,
      personalDone: personalDone,
      addressDone: addressDone,
      kycDone: kycVerified,
      kycStatus: kycStatus,
      percent: percent,
    );
  }

  static bool _isTruthy(dynamic v) {
    if (v == true || v == 1) return true;
    final s = '$v'.trim().toLowerCase();
    return s == 'true' || s == '1';
  }
}
