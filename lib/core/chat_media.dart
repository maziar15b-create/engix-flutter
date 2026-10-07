import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'project_media.dart' show PickedMedia;

const kChatBucket = 'messenger-attachments';
const kChatMaxBytes = 60 * 1024 * 1024;

const _mimeByExt = <String, String>{
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.heic': 'image/heic',
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.webm': 'video/webm',
  '.mkv': 'video/x-matroska',
  '.3gp': 'video/3gpp',
  '.m4a': 'audio/mp4',
  '.aac': 'audio/aac',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.wav': 'audio/wav',
  '.pdf': 'application/pdf',
  '.doc': 'application/msword',
  '.docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.xls': 'application/vnd.ms-excel',
  '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  '.zip': 'application/zip',
  '.dwg': 'application/octet-stream',
};

String chatExt(String name) {
  final i = name.lastIndexOf('.');
  return i >= 0 ? name.substring(i).toLowerCase() : '';
}

String chatMime(String name, String? given) {
  if (given != null && given.isNotEmpty && given != 'application/octet-stream') {
    return given;
  }
  return _mimeByExt[chatExt(name)] ?? 'application/octet-stream';
}

String chatTypeFromMime(String mime) {
  if (mime.startsWith('image/')) return 'image';
  if (mime.startsWith('video/')) return 'video';
  if (mime.startsWith('audio/')) return 'voice';
  if (mime == 'application/pdf') return 'pdf';
  if (mime == 'application/msword' || mime.contains('wordprocessingml')) {
    return 'word';
  }
  return 'file';
}

class ChatAttachment {
  final String type;
  final String url;
  final Map<String, dynamic> meta;
  const ChatAttachment(this.type, this.url, this.meta);
}

String newMessageId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-'
      '${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

Future<ChatAttachment> uploadChatFile(
  PickedMedia f,
  String conversationId, {
  int? durationSec,
}) async {
  final mime = chatMime(f.name, f.mime);
  final type = chatTypeFromMime(mime);
  if (f.bytes.length > kChatMaxBytes) {
    throw Exception('حجم فایل بیشتر از حد مجاز (۶۰ مگابایت) است.');
  }
  final rand =
      Random().nextInt(1 << 31).toRadixString(36).padRight(6, '0').substring(0, 6);
  var ext = chatExt(f.name);
  if (ext.isEmpty && type == 'voice') ext = '.m4a';
  final path = '$conversationId/${DateTime.now().millisecondsSinceEpoch}-$rand$ext';
  final st = Supabase.instance.client.storage.from(kChatBucket);
  try {
    await st.uploadBinary(path, f.bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false));
  } catch (e) {
    throw Exception('آپلود ناموفق بود: $e');
  }
  return ChatAttachment(type, st.getPublicUrl(path), {
    'name': f.name,
    'size': f.bytes.length,
    'mime_type': mime,
    'storage_path': path,
    if (durationSec != null) 'duration': durationSec,
  });
}

Future<PickedMedia?> pickChatImage({bool camera = false}) async {
  final x = await ImagePicker().pickImage(
    source: camera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 85,
    maxWidth: 2048,
  );
  if (x == null) return null;
  return PickedMedia(await x.readAsBytes(), x.name, x.mimeType);
}

Future<PickedMedia?> pickChatVideo() async {
  final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (x == null) return null;
  return PickedMedia(await x.readAsBytes(), x.name, x.mimeType);
}

Future<PickedMedia?> pickChatFile() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  final f = r?.files.single;
  if (f == null || f.bytes == null) return null;
  return PickedMedia(f.bytes!, f.name, null);
}

Future<PickedMedia> mediaFromPath(String path, String name) async {
  final bytes = await File(path).readAsBytes();
  return PickedMedia(bytes, name, null);
}

Future<Position> currentChatPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('GPS گوشی خاموش است.');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw Exception('دسترسی به موقعیت مکانی داده نشده است.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
}
