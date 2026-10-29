import 'dart:io';

import 'package:app_installer_plus/core/apiServices/api_service.dart';
import 'package:app_installer_plus/core/helper/app_helper.dart';
import 'package:path_provider/path_provider.dart';

import 'app_installer_plus_platform_interface.dart';

/// The main entry point for the App Installer Plus plugin.
///
/// This singleton class provides methods to download APK files from a direct URL,
/// track their download progress, automatically trigger the Android installation
/// prompt, and manage the downloaded files on the device storage.
class AppInstallerPlus {
  static final AppInstallerPlus _instance = AppInstallerPlus._internal();

  /// Returns the singleton instance of [AppInstallerPlus].
  factory AppInstallerPlus() {
    return _instance;
  }

  AppInstallerPlus._internal();

  /// Downloads an APK from the given URL and installs it automatically on Android devices.
  ///
  /// This method streams the file to local storage and triggers the Android package
  /// installer upon completion. It provides detailed callbacks for tracking the network
  /// progress, speed, and time remaining.
  ///
  /// Parameters:
  /// * [downloadFileUrl]: The direct URL to the `.apk` file.
  /// * [onProgress]: Callback returning the download progress as a double (0.0 to 1.0).
  /// * [onError]: (Deprecated) Callback for legacy error handling. Use try-catch with `FileDownloadException` instead.
  /// * [onTimeLeft]: Callback returning a formatted string of the estimated time remaining.
  /// * [onSpeed]: Callback returning a formatted string of the current download speed.
  /// * [onTotalSize]: Callback returning a formatted string of the total file size.
  /// * [onDownloadedSize]: Callback returning a formatted string of the bytes downloaded so far.
  /// * [downloadFileName]: Optional custom name for the downloaded file (without the `.apk` extension). Defaults to "downloadApk".
  /// * [deleteOnError]: If true, automatically deletes the partial file if the download fails due to a network or server error. Defaults to false.
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
    await AppInstallerPlusPlatform.instance.downloadAndInstallApk(
      downloadFileUrl: downloadFileUrl,
      onError: onError,
      onProgress: onProgress,
      downloadFileName: downloadFileName,
      onTimeLeft: onTimeLeft,
      onSpeed: onSpeed,
      onTotalSize: onTotalSize,
      onDownloadedSize: onDownloadedSize,
      deleteOnError: deleteOnError,
    );
  }

  /// Deletes a fully downloaded APK from the device's storage.
  ///
  /// This is useful for freeing up storage space after a successful installation.
  ///
  /// Parameters:
  /// * [downloadFileName]: The name of the file to delete (without the `.apk` extension).
  ///   Must match the name used in [downloadAndInstallApk]. Defaults to "downloadApk".
  ///
  /// Returns `true` if the file was successfully deleted, or `false` if the file
  /// did not exist or an error occurred.
  Future<bool> removedDownloadedApk({String? downloadFileName}) async {
    try {
      Directory? downloadDirectory = await getExternalStorageDirectory();
      if (downloadDirectory == null) return false;

      String apkPath =
          "${downloadDirectory.path}/${downloadFileName ?? 'downloadApk'}.apk";

      File file = File(apkPath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (e, sc) {
      printLog(e, stackTrace: sc);
      return false;
    }
    return false;
  }

  /// Cancels the currently active download.
  ///
  /// Parameters:
  /// * [deletePartialDownload]: If set to `true`, the incomplete `.apk` file will be
  ///   permanently deleted from the device's storage. If `false` (default), the
  ///   partial file remains on the device.
  Future<void> cancelDownload({bool deletePartialDownload = false}) async {
    await ApiService().cancelDownload(
      deletePartialDownload: deletePartialDownload,
    );
  }
}
