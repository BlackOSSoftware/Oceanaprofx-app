import 'dart:developer';

const String apkName = "downloadApk.apk";

void printLog(dynamic message, {StackTrace? stackTrace}) {
  bool showOnConsole = true;
  if (showOnConsole) {
    log("My Log :: ${message.toString()}");
    if (stackTrace != null) {
      log(stackTrace.toString());
    }
  }
}
