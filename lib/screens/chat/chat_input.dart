import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/chat_media.dart';
import '../../core/project_media.dart' show PickedMedia;
import '../../core/theme.dart';

class ChatInput extends StatefulWidget {
  final Future<void> Function(String text) onSendText;
  final void Function(String kind) onAttach;
  final Future<void> Function(PickedMedia voice, int seconds) onSendVoice;
  final String? replyText;
  final VoidCallback? onCancelReply;

  const ChatInput({
    super.key,
    required this.onSendText,
    required this.onAttach,
    required this.onSendVoice,
    this.replyText,
    this.onCancelReply,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _ctl = TextEditingController();
  final _rec = AudioRecorder();
  bool _hasText = false;
  bool _recording = false;
  int _secs = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctl.addListener(() {
      final has = _ctl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    _rec.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty) return;
    _ctl.clear();
    await widget.onSendText(t);
  }

  Future<void> _startRecording() async {
    try {
      if (!await _rec.hasPermission()) {
        _snack('اجازه‌ی دسترسی به میکروفون داده نشده است.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() {
        _recording = true;
        _secs = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secs++);
      });
    } catch (e) {
      _snack('شروع ضبط ممکن نشد.');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    _timer?.cancel();
    final secs = _secs;
    setState(() => _recording = false);
    try {
      if (!send) {
        await _rec.cancel();
        return;
      }
      final path = await _rec.stop();
      if (path == null) return;
      if (secs < 1) {
        _snack('پیام صوتی خیلی کوتاه است.');
        return;
      }
      final media = await mediaFromPath(path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await widget.onSendVoice(media, secs);
    } catch (_) {
      _snack('ارسال پیام صوتی ممکن نشد.');
    }
  }

  void _attachMenu() {
    Widget item(IconData icon, Color color, String label, String kind) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).pop();
          widget.onAttach(kind);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: color.withAlpha(45),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withAlpha(120))),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: C.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              item(Icons.photo_library, const Color(0xFF8E7CFF), 'گالری', 'gallery'),
              item(Icons.photo_camera, const Color(0xFFFF6B8B), 'دوربین', 'camera'),
              item(Icons.videocam, const Color(0xFFFFA14A), 'ویدیو', 'video'),
              item(Icons.insert_drive_file, const Color(0xFF4FC3F7), 'فایل', 'file'),
              item(Icons.location_on, const Color(0xFF2ED573), 'موقعیت', 'location'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: C.bg1,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.replyText != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(
                color: C.bg3,
                borderRadius: BorderRadius.circular(10),
                border: const Border(right: BorderSide(color: C.redLight, width: 3)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(widget.replyText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: C.soft, fontSize: 12.5)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18, color: C.muted),
                  onPressed: widget.onCancelReply,
                ),
              ]),
            ),
          _recording ? _recorderRow() : _inputRow(),
        ]),
      ),
    );
  }

  Widget _recorderRow() {
    return Row(children: [
      IconButton(
        icon: const Icon(Icons.delete_outline, color: C.danger),
        onPressed: () => _stopRecording(send: false),
      ),
      const Icon(Icons.fiber_manual_record, color: C.danger, size: 14),
      const SizedBox(width: 8),
      Text(formatRecDuration(_secs),
          style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(width: 10),
      const Expanded(
          child: Text('در حال ضبط...', style: TextStyle(color: C.soft, fontSize: 12.5))),
      IconButton.filled(
        style: IconButton.styleFrom(
            backgroundColor: C.red, foregroundColor: Colors.white),
        onPressed: () => _stopRecording(send: true),
        icon: const Icon(Icons.send),
      ),
    ]);
  }

  Widget _inputRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      IconButton(
        icon: const Icon(Icons.attach_file, color: C.soft),
        onPressed: _attachMenu,
      ),
      Expanded(
        child: TextField(
          controller: _ctl,
          minLines: 1,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(hintText: 'پیام...'),
        ),
      ),
      const SizedBox(width: 6),
      _hasText
          ? IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: C.red, foregroundColor: Colors.white),
              onPressed: _send,
              icon: const Icon(Icons.send),
            )
          : IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: C.red, foregroundColor: Colors.white),
              onPressed: _startRecording,
              icon: const Icon(Icons.mic),
            ),
    ]);
  }
}

String formatRecDuration(int s) {
  final m = (s ~/ 60).toString().padLeft(2, '0');
  final x = (s % 60).toString().padLeft(2, '0');
  return '$m:$x';
}
