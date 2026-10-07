import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme.dart';

String messagePreview(String type, String? content, {bool deleted = false}) {
  if (deleted) return 'پیام حذف شد';
  switch (type) {
    case 'image':
      return '📷 تصویر';
    case 'video':
      return '🎬 ویدیو';
    case 'voice':
      return '🎤 پیام صوتی';
    case 'pdf':
      return '📄 فایل PDF';
    case 'word':
      return '📄 فایل Word';
    case 'file':
      return '📎 فایل';
    case 'location':
      return '📍 موقعیت مکانی';
    default:
      return (content ?? '').toString();
  }
}

String formatSize(num? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String formatDuration(int sec) {
  final m = (sec ~/ 60).toString().padLeft(2, '0');
  final s = (sec % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

Future<void> openExternal(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

class MessageTicks extends StatelessWidget {
  final bool pending;
  final bool failed;
  final bool read;
  const MessageTicks(
      {super.key,
      required this.pending,
      required this.failed,
      required this.read});

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const Icon(Icons.error_outline, size: 14, color: C.danger);
    }
    if (pending) {
      return const Icon(Icons.access_time, size: 13, color: C.soft);
    }
    if (read) {
      return const Icon(Icons.done_all, size: 16, color: Color(0xFF4FC3F7));
    }
    return const Icon(Icons.done, size: 16, color: C.soft);
  }
}

class MessageContent extends StatelessWidget {
  final Map<String, dynamic> m;
  const MessageContent({super.key, required this.m});

  Map<String, dynamic> get _meta {
    final x = m['file_meta'];
    return x is Map ? Map<String, dynamic>.from(x) : <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    final type = (m['type'] ?? 'text').toString();
    final content = (m['content'] ?? '').toString();
    final url = (m['file_url'] ?? '').toString();
    final uploading = m['_pending'] == true && url.isEmpty && type != 'text' && type != 'location';

    if (uploading) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Flexible(
            child: Text(messagePreview(type, content),
                style: const TextStyle(color: C.soft))),
      ]);
    }

    switch (type) {
      case 'image':
        return _image(context, url, content);
      case 'video':
        return _video(context, url, content);
      case 'voice':
        return VoiceBubble(url: url, durationSec: (_meta['duration'] as num?)?.toInt());
      case 'location':
        return _location(context);
      case 'pdf':
      case 'word':
      case 'file':
        return _file(type, url);
      default:
        return SelectableText(content,
            style: const TextStyle(height: 1.6, color: C.text));
    }
  }

  Widget _image(BuildContext context, String url, String caption) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ImageViewerScreen(url: url))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            url,
            width: 230,
            fit: BoxFit.cover,
            loadingBuilder: (c, child, p) => p == null
                ? child
                : const SizedBox(
                    width: 230,
                    height: 160,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorBuilder: (_, __, ___) => const SizedBox(
                width: 230,
                height: 120,
                child: Center(child: Icon(Icons.broken_image, color: C.muted))),
          ),
        ),
      ),
      if (caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(caption, style: const TextStyle(height: 1.5)),
        ),
    ]);
  }

  Widget _video(BuildContext context, String url, String caption) {
    final meta = _meta;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => VideoViewerScreen(url: url))),
        child: Container(
          width: 230,
          height: 140,
          decoration: BoxDecoration(
              color: Colors.black54, borderRadius: BorderRadius.circular(10)),
          child: Stack(alignment: Alignment.center, children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  color: Color(0x99000000), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, size: 34, color: Colors.white),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Text(formatSize(meta['size'] as num?),
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ),
          ]),
        ),
      ),
      if (caption.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(caption, style: const TextStyle(height: 1.5)),
        ),
    ]);
  }

  Widget _file(String type, String url) {
    final meta = _meta;
    final name = (meta['name'] ?? 'فایل').toString();
    final icon = type == 'pdf'
        ? Icons.picture_as_pdf
        : (type == 'word' ? Icons.description : Icons.insert_drive_file);
    return InkWell(
      onTap: url.isEmpty ? null : () => openExternal(url),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 190, maxWidth: 240),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: C.redLight),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(formatSize(meta['size'] as num?),
                  style: const TextStyle(fontSize: 11, color: C.soft)),
            ]),
          ),
          const Icon(Icons.download_rounded, size: 20, color: C.soft),
        ]),
      ),
    );
  }

  Widget _location(BuildContext context) {
    final meta = _meta;
    final lat = (meta['lat'] as num?)?.toDouble();
    final lng = (meta['lng'] as num?)?.toDouble();
    return InkWell(
      onTap: (lat == null || lng == null)
          ? null
          : () => openExternal(
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
      child: SizedBox(
        width: 220,
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
                color: const Color(0x33FFFFFF),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.location_on, color: C.redLight, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('موقعیت مکانی',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                  (lat == null || lng == null)
                      ? ''
                      : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 11, color: C.soft)),
              const SizedBox(height: 2),
              const Text('مشاهده روی نقشه',
                  style: TextStyle(fontSize: 11, color: C.redLight)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class VoiceBubble extends StatefulWidget {
  final String url;
  final int? durationSec;
  const VoiceBubble({super.key, required this.url, this.durationSec});

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription> _subs = [];
  PlayerState _state = PlayerState.stopped;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.durationSec != null) _dur = Duration(seconds: widget.durationSec!);
    _subs.add(_player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    }));
    _subs.add(_player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _pos = p);
    }));
    _subs.add(_player.onDurationChanged.listen((d) {
      if (mounted && d.inMilliseconds > 0) setState(() => _dur = d);
    }));
    _subs.add(_player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _pos = Duration.zero);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (widget.url.isEmpty) return;
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playing = _state == PlayerState.playing;
    final total = _dur.inMilliseconds;
    final value = total <= 0 ? 0.0 : (_pos.inMilliseconds / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 220,
      child: Row(children: [
        InkWell(
          onTap: _toggle,
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: C.red, shape: BoxShape.circle),
            child: Icon(playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: SliderComponentShape.noOverlay,
                activeTrackColor: C.redLight,
                inactiveTrackColor: const Color(0x33FFFFFF),
                thumbColor: C.redLight,
              ),
              child: Slider(
                value: value,
                onChanged: total <= 0
                    ? null
                    : (v) => _player.seek(Duration(milliseconds: (v * total).round())),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                formatDuration(
                    (playing || _pos > Duration.zero ? _pos : _dur).inSeconds),
                style: const TextStyle(fontSize: 11, color: C.soft),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String url;
  const ImageViewerScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openExternal(url)),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class VideoViewerScreen extends StatefulWidget {
  final String url;
  const VideoViewerScreen({super.key, required this.url});

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late final VideoPlayerController _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _ready = true);
      _c.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openExternal(widget.url)),
        ],
      ),
      body: Center(
        child: _failed
            ? const Text('پخش ویدیو ممکن نیست.', style: TextStyle(color: C.soft))
            : !_ready
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _c.value.aspectRatio,
                        child: GestureDetector(
                          onTap: () =>
                              _c.value.isPlaying ? _c.pause() : _c.play(),
                          child: VideoPlayer(_c),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: VideoProgressIndicator(_c,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                                playedColor: C.redLight)),
                      ),
                      IconButton(
                        iconSize: 44,
                        color: Colors.white,
                        icon: Icon(_c.value.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle),
                        onPressed: () =>
                            _c.value.isPlaying ? _c.pause() : _c.play(),
                      ),
                    ],
                  ),
      ),
    );
  }
}
