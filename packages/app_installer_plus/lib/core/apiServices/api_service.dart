import 'dart:developer';
import 'dart:io';

import 'package:app_installer_plus/core/enums/download_error_type.dart';
import 'package:app_installer_plus/core/exceptions/file_download_exception.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// A singleton service responsible for managing APK downloads.
///
/// This class handles network operations, tracking download progress,
/// calculating download speed, and safely managing file cancellations
/// and partial deletions.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  late final Dio _dio;

  CancelToken? _cancelToken;
  bool _isDownloading = false;
  String? _downloadPath;

  /// Returns the singleton instance of [ApiService].
  factory ApiService() {
    return _instance;
  }

  ApiService._internal() : _dio = Dio();

  /// Downloads a file from the provided URL to the device's external storage.
  ///
  /// Prevents concurrent downloads by throwing a [FileDownloadException] with
  /// [DownloadErrorType.alreadyRunning] if a download is currently active.
  ///
  /// The file is saved in the external storage directory with the name
  /// specified by [downloadFileName] (defaults to "downloadApk.apk").
  ///
  /// Parameters:
  /// * [downloadFileUrl]: The direct URL to the APK file.
  /// * [onProgress]: Callback returning the download progress as a double (0.0 to 1.0).
  /// * [onError]: Callback for legacy error handling.
  /// * [onTimeLeft]: Callback returning a formatted string of the estimated time remaining.
  /// * [onSpeed]: Callback returning a formatted string of the current download speed.
  /// * [onTotalSize]: Callback returning a formatted string of the total file size.
  /// * [onDownloadedSize]: Callback returning a formatted string of the bytes downloaded so far.
  /// * [downloadFileName]: Optional custom name for the downloaded file (without the .apk extension).
  /// * [deleteOnError]: If true, automatically deletes the partial file if the download fails due to a network or server error. Defaults to false.
  ///
  /// Returns the absolute path to the downloaded file on success, or null if handled via legacy error.
  Future<String?> downloadFile({
    required String downloadFileUrl,
    void Function(double progress)? onProgress,
    @Deprecated(
      'Use a try-catch block to handle FileDownloadException instead.',
    )
    void Function(String error)? onError,
    void Function(String timeLeft)? onTimeLeft,
    void Function(String speed)? onSpeed,
    void Function(String totalSize)? onTotalSize,
    void Function(String downloadedSize)? onDownloadedSize,
    String? downloadFileName,
    bool deleteOnError = false,
  }) async {
    if (_isDownloading) {
      final exception = FileDownloadException(
        type: DownloadErrorType.alreadyRunning,
        originalError:
            "A download task is currently active. Please wait for it to finish or cancel it.",
      );

      return _handleErrorBridge(
        exception,
        "Download already in progress",
        onError,
      );
    }

    _isDownloading = true;
    _cancelToken = CancelToken();

    int lastBytes = 0;
    DateTime lastUpdateTime = DateTime.now();

    try {
      Directory? directory = await getExternalStorageDirectory();

      if (directory == null) {
        final exception = FileDownloadException(
          type: DownloadErrorType.storageAccessDenied,
          originalError: "Unable to access storage directory",
        );
        return _handleErrorBridge(
          exception,
          "Unable to access storage directory",
          onError,
        );
      }

      String savePath =
          "${directory.path}/${downloadFileName ?? "downloadApk"}.apk";

      _downloadPath = savePath;

      Response response = await _dio.download(
        downloadFileUrl,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (count, total) {
          if (total > 0) {
            if (onProgress != null) {
              onProgress(count / total);
            }

            if (onTotalSize != null) {
              onTotalSize(_formatBytes(total));
            }

            if (onDownloadedSize != null) {
              onDownloadedSize(_formatBytes(count));
            }

            DateTime now = DateTime.now();
            Duration interval = now.difference(lastUpdateTime);

            if (interval.inMilliseconds >= 500 || count == total) {
              int bytesSinceLast = count - lastBytes;
              double secondsSinceLast = interval.inMilliseconds / 1000.0;

              if (secondsSinceLast > 0) {
                double speedBps = bytesSinceLast / secondsSinceLast;

                if (onSpeed != null) {
                  onSpeed(_formatSpeed(speedBps));
                }

                if (onTimeLeft != null && speedBps > 0) {
                  double remainingBytes = (total - count).toDouble();
                  double remainingSeconds = remainingBytes / speedBps;
                  onTimeLeft(_formatTimeLeft(remainingSeconds));
                }
              }

              lastBytes = count;
              lastUpdateTime = now;
            }
          }
        },
      );

      if (response.statusCode == 200) {
        _downloadPath = null;
        return savePath;
      } else {
        // Add the cleanup here too!
        if (deleteOnError && _downloadPath != null) {
          File file = File(_downloadPath!);
          if (await file.exists()) {
            try {
              await file.delete();
              log(
                "Partial file deleted automatically due to bad response code.",
              );
            } catch (_) {}
          }
          _downloadPath = null;
        }
        final exception = FileDownloadException(
          type: DownloadErrorType.badResponse,
          statusCode: response.statusCode,
          originalError: "Server returned status: ${response.statusCode}",
        );
        return _handleErrorBridge(
          exception,
          "Unable to download the file",
          onError,
        );
      }
    } on DioException catch (e, sc) {
      log("DioException in downloadFile", error: e, stackTrace: sc);

      if (deleteOnError &&
          e.type != DioExceptionType.cancel &&
          _downloadPath != null) {
        File file = File(_downloadPath!);
        if (await file.exists()) {
          try {
            await file.delete();
            log("Partial file deleted automatically due to DioException.");
          } catch (_) {}
        }
        _downloadPath = null; // Clear state after deleting
      }

      final exception = FileDownloadException(
        type: _mapDioErrorToEnum(e.type),
        statusCode: e.response?.statusCode,
        originalError: e,
      );
      String legacyErrorString = _getLegacyErrorMessage(e);
      return _handleErrorBridge(exception, legacyErrorString, onError);
    } catch (e, sc) {
      log("Unknown Exception in downloadFile", error: e, stackTrace: sc);
      // 3. Add Auto-Cleanup for unknown errors too
      if (deleteOnError && _downloadPath != null) {
        File file = File(_downloadPath!);
        if (await file.exists()) {
          try {
            await file.delete();
            log("Partial file deleted automatically due to Unknown Exception.");
          } catch (_) {}
        }
        _downloadPath = null; // Clear state after deleting
      }
      final exception = FileDownloadException(
        type: DownloadErrorType.unknown,
        originalError: e,
      );
      return _handleErrorBridge(
        exception,
        "Error Occurred while downloading the file",
        onError,
      );
    } finally {
      _isDownloading = false;
    }
  }

  /// Cancels the currently active download.
  ///
  /// If [deletePartialDownload] is true, this method will also attempt to
  /// permanently delete the incomplete file from the device's storage.
  Future<void> cancelDownload({bool deletePartialDownload = false}) async {
    String? pathToDelete = _downloadPath;

    _cancelToken?.cancel();

    if (deletePartialDownload && pathToDelete != null) {
      _downloadPath = null;
      File file = File(pathToDelete);
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          log("Error deleting partial file during cancellation", error: e);
        }
      }
    }
  }

  /// Formats the raw byte size into a readable string (e.g., GB, MB, KB).
  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes >= 1024 * 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(2)} TB";
    } else if (bytes >= 1024 * 1024 * 1024) {
      return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB";
    } else if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    } else if (bytes >= 1024) {
      return "${(bytes / 1024).toStringAsFixed(2)} KB";
    } else {
      return "$bytes B";
    }
  }

  /// Formats raw seconds into a clean digital clock string (e.g., "02:30" or "1:15:00").
  String _formatTimeLeft(double totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = ((totalSeconds % 3600) ~/ 60);
    int seconds = (totalSeconds % 60).toInt();

    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      String hoursStr = hours.toString().padLeft(2, '0');
      return "$hoursStr:$minutesStr:$secondsStr";
    } else {
      return "$minutesStr:$secondsStr";
    }
  }

  /// Formats raw bytes per second into a readable speed string.
  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond >= 1024 * 1024) {
      return "${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s";
    } else if (bytesPerSecond >= 1024) {
      return "${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s";
    } else {
      return "${bytesPerSecond.toStringAsFixed(0)} B/s";
    }
  }

  /// Routes the error to the callback OR throws the exception if no callback is provided.
  String? _handleErrorBridge(
    FileDownloadException exception,
    String legacyString,
    void Function(String)? onErrorCallback,
  ) {
    if (onErrorCallback != null) {
      onErrorCallback(legacyString);
      return null;
    } else {
      throw exception;
    }
  }

  /// Maps Dio's internal exception types to the custom [DownloadErrorType] enum.
  DownloadErrorType _mapDioErrorToEnum(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return DownloadErrorType.networkTimeout;
      case DioExceptionType.badResponse:
        return DownloadErrorType.badResponse;
      case DioExceptionType.connectionError:
        return DownloadErrorType.noInternetConnection;
      case DioExceptionType.cancel:
        return DownloadErrorType.cancelled;
      default:
        return DownloadErrorType.unknown;
    }
  }

  /// Returns legacy error messages to prevent breaking changes for existing apps.
  String _getLegacyErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Request Timeout\nTry again later";
      case DioExceptionType.badResponse:
        return "Bad Response : ${e.error.toString()}";
      case DioExceptionType.cancel:
        return "Download cancelled";
      case DioExceptionType.unknown:
        return "Error : ${e.error.toString()}";
      case DioExceptionType.connectionError:
        return "Check your Internet connection and try again";
      default:
        return "Something went wrong";
    }
  }
}
