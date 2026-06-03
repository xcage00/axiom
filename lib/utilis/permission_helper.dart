import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
}