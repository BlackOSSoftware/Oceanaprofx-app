import 'package:app_installer_plus/core/enums/download_error_type.dart';

class FileDownloadException implements Exception {
  final DownloadErrorType type;
  final int? statusCode;
  final dynamic originalError;

  FileDownloadException({
    required this.type,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => "FileDownloadException: ${type.name}";
}
