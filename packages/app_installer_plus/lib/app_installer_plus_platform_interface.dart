import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'app_installer_plus_method_channel.dart';

abstract class AppInstallerPlusPlatform extends PlatformInterface {
  /// Constructs a AppInstallerPlusPlatform.
  AppInstallerPlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static AppInstallerPlusPlatform _instance = MethodChannelAppInstallerPlus();

  /// The default instance of [AppInstallerPlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelAppInstallerPlus].
  static AppInstallerPlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AppInstallerPlusPlatform] when
  /// they register themselves.
  static set instance(AppInstallerPlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

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
  }) {
    throw UnimplementedError(
      'downloadAndInstallApk() has not been implemented.',
    );
  }
}
