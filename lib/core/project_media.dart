import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// معادل lib/uploadProjectMedia.js در وب
const kMediaBucket = 'project-media';
const kMaxMediaBytes = 60 * 1024 * 1024;

const _allowed = <String, List<String>>{
  'image': ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
  'video': ['video/mp4', 'video/webm', 'video/quicktime'],
  'voice': ['audio/webm', 'audio/mp4', 'audio/mpeg', 'audio/ogg', 'audio/wav'],
};

const _mimeByExt = <String, String>{
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.mp4': 'video/mp4',
  '.webm': 'video/webm',
  '.mov': 'video/quicktime',
  '.m4a': 'audio/mp4',
  '.mp3': 'audio/mpeg',
  '.ogg': 'audio/ogg',
  '.wav': 'audio/wav',
  '.pdf': 'application/pdf',
};

String _ext(String name) {
  final i = name.lastIndexOf('.');
  return i >= 0 ? name.substring(i).toLowerCase() : '';
}

String mimeFromName(String name) =>
    _mimeByExt[_ext(name)] ?? 'application/octet-stream';

String? detectMediaType(String mime) {
  for (final e in _allowed.entries) {
    if (e.value.contains(mime)) return e.key;
  }
  return null;
}

class PickedMedia {
  final Uint8List bytes;
  final String name;
  final String? mime;
  const PickedMedia(this.bytes, this.name, this.mime);
}

class UploadedMedia {
  final String type;
  final String url;
  const UploadedMedia(this.type, this.url);
  Map<String, dynamic> toJson() => {'type': type, 'url': url};
}

Future<UploadedMedia> uploadProjectMedia(PickedMedia f, String projectId) async {
  final mime = (f.mime != null && f.mime!.isNotEmpty) ? f.mime! : mimeFromName(f.name);
  final type = detectMediaType(mime);
  if (type == null) throw Exception('نوع فایل پشتیبانی نمی‌شود.');
  if (f.bytes.length > kMaxMediaBytes) {
    throw Exception('حجم فایل بیشتر از حد مجاز (۶۰ مگابایت) است.');
  }
  final rand = Random().nextInt(1 << 31).toRadixString(36).padRight(6, '0').substring(0, 6);
  var ext = _ext(f.name);
  if (ext.isEmpty && type == 'voice') ext = '.webm';
  final path = '$projectId/${DateTime.now().millisecondsSinceEpoch}-$rand$ext';
  final st = Supabase.instance.client.storage.from(kMediaBucket);
  try {
    await st.uploadBinary(path, f.bytes,
        fileOptions: FileOptions(contentType: mime, upsert: false));
  } catch (e) {
    throw Exception('آپلود ناموفق بود: $e');
  }
  return UploadedMedia(type, st.getPublicUrl(path));
}

Future<PickedMedia?> pickImageMedia() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (x == null) return null;
  return PickedMedia(await x.readAsBytes(), x.name, x.mimeType);
}

Future<PickedMedia?> pickVideoMedia() async {
  final x = await ImagePicker().pickVideo(source: ImageSource.gallery);
  if (x == null) return null;
  return PickedMedia(await x.readAsBytes(), x.name, x.mimeType);
}

Future<PickedMedia?> pickAudioMedia() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
  final f = r?.files.single;
  if (f == null || f.bytes == null) return null;
  return PickedMedia(f.bytes!, f.name, null);
}

Future<PickedMedia?> pickAnyMedia() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  final f = r?.files.single;
  if (f == null || f.bytes == null) return null;
  return PickedMedia(f.bytes!, f.name, null);
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}
