import 'package:app_installer_plus/core/apiServices/api_service.dart';
import 'package:app_installer_plus/core/exceptions/file_download_exception.dart';
import 'package:app_installer_plus/core/enums/download_error_type.dart';
import 'package:app_installer_plus/core/helper/app_helper.dart';
import 'package:flutter/services.dart';

import 'app_installer_plus_platform_interface.dart';

/// An implementation of [AppInstallerPlusPlatform] that uses method channels.
///
/// This class handles the communication between the Dart code and the native
/// Android platform to trigger the APK installation process after a successful download.
class MethodChannelAppInstallerPlus extends AppInstallerPlusPlatform {
  /// The method channel used to interact with the native platform.
  final MethodChannel _channel = const MethodChannel('app_installer_plus');

  /// Downloads an APK file and invokes the native method channel to install it.
  ///
  /// This method delegates the downloading process to [ApiService].
  /// If the download is successful and a valid file path is returned, it invokes
  /// the `downloadAndInstallApk` method on the native platform channel.
  ///
  /// Parameters:
  /// * [downloadFileUrl]: The direct URL to the `.apk` file. Must not be empty.
  /// * [onProgress]: Callback returning the download progress as a double (0.0 to 1.0).
  /// * [onError]: (Deprecated) Callback for legacy error handling. Use try-catch instead.
  /// * [onTimeLeft]: Callback returning a formatted string of the estimated time remaining.
  /// * [onSpeed]: Callback returning a formatted string of the current download speed.
  /// * [onTotalSize]: Callback returning a formatted string of the total file size.
  /// * [onDownloadedSize]: Callback returning a formatted string of the bytes downloaded so far.
  /// * [downloadFileName]: Optional custom name for the downloaded file (without the `.apk` extension).
  /// * [deleteOnError]: If `true`, automatically deletes the incomplete file if the download fails. Defaults to `false`.
  ///
  /// Throws:
  /// * [ArgumentError] if the [downloadFileUrl] is empty.
  /// * [FileDownloadException] for network, storage, or platform-specific errors.
  @override
  Future<void> downloadAndInstallApk({
    required String downloadFileUrl,
    void Function(double progress)? onProgress,
    @Deprecated('Use try-catch with FileDownloadException instead.')
    void Function(String error)? onError,
    void Function(String timeLeft)? onTimeLeft,
    void Function(String speed)? onSpeed,
    void Function(String totalSize)? onTotalSize,
    void Function(String downloadedSize)? onDownloadedSize,
    String? downloadFileName,
    bool deleteOnError = false,
  }) async {
    try {
      if (downloadFileUrl.trim().isEmpty) {
        throw ArgumentError("Download File Url cannot be empty");
      }

      // 1. Await ApiService directly. Do NOT pass onSuccess/onError here anymore.
      // Let ApiService throw the Exception naturally.
      String? filePath = await ApiService().downloadFile(
        downloadFileUrl: downloadFileUrl,
        downloadFileName: downloadFileName,
        onProgress: onProgress,
        onTimeLeft: onTimeLeft,
        onSpeed: onSpeed,
        onTotalSize: onTotalSize,
        onDownloadedSize: onDownloadedSize,
        deleteOnError: deleteOnError,
      );

      // 2. If successful, trigger the native installation
      if (filePath != null) {
        await _channel.invokeMethod<String>('downloadAndInstallApk', {
          "path": filePath,
        });
      }
    } on FileDownloadException catch (e, sc) {
      printLog(e.toString(), stackTrace: sc);
      _handleErrorBridge(e, "Error occurred during download", onError);
    } on PlatformException catch (e, sc) {
      printLog(e.toString(), stackTrace: sc);
      final exception = FileDownloadException(
        type: DownloadErrorType.unknown,
        originalError: e,
      );
      _handleErrorBridge(
        exception,
        e.message ?? "Platform Exception occurred",
        onError,
      );
    } catch (e, sc) {
      printLog(e.toString(), stackTrace: sc);
      final exception = FileDownloadException(
        type: DownloadErrorType.unknown,
        originalError: e,
      );
      _handleErrorBridge(exception, e.toString(), onError);
    }
  }

  /// A private helper to route the error to the legacy callback OR throw it.
  ///
  /// If the developer provided the deprecated [onErrorCallback], it sends the
  /// [legacyMessage] string to prevent breaking changes. Otherwise, it throws
  /// the modern [exception].
  void _handleErrorBridge(
    FileDownloadException exception,
    String legacyMessage,
    void Function(String)? onErrorCallback,
  ) {
    if (onErrorCallback != null) {
      // Legacy Mode: The user provided the old callback. Send them the string.
      onErrorCallback(legacyMessage);
    } else {
      // Modern Mode: The user wants to use try-catch. Throw the exception!
      throw exception;
    }
  }
}
