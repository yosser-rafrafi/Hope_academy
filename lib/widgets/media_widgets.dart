import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../core/app_colors.dart';
import '../services/storage_service.dart';

// ─── Picker (create forms) ────────────────────────────────────────────────────

/// Lets the user attach photos & videos. The parent keeps the list and
/// uploads it on save (see `StorageService.uploadAll`).
class MediaPickerField extends StatelessWidget {
  final List<XFile> files;
  final ValueChanged<List<XFile>> onChanged;
  final int maxItems;
  final bool enabled;

  const MediaPickerField({
    super.key,
    required this.files,
    required this.onChanged,
    this.maxItems = 10,
    this.enabled = true,
  });

  Future<void> _add(BuildContext context, String kind) async {
    final storage = StorageService();
    final next = List<XFile>.from(files);
    try {
      switch (kind) {
        case 'photos':
          next.addAll(await storage.pickImages());
          break;
        case 'camera':
          final f = await storage.takePhoto();
          if (f != null) next.add(f);
          break;
        case 'video':
          final v = await storage.pickVideo();
          if (v != null) next.add(v);
          break;
        case 'videocam':
          final v = await storage.pickVideo(fromCamera: true);
          if (v != null) next.add(v);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add media: $e')));
      }
      return;
    }
    onChanged(next.take(maxItems).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AddChip(icon: Icons.photo_library_rounded, label: 'Photos', color: AppColors.sky,
                onTap: enabled && files.length < maxItems ? () => _add(context, 'photos') : null),
            _AddChip(icon: Icons.photo_camera_rounded, label: 'Camera', color: AppColors.mint,
                onTap: enabled && files.length < maxItems ? () => _add(context, 'camera') : null),
            _AddChip(icon: Icons.video_library_rounded, label: 'Video', color: AppColors.grape,
                onTap: enabled && files.length < maxItems ? () => _add(context, 'video') : null),
            _AddChip(icon: Icons.videocam_rounded, label: 'Record', color: AppColors.coral,
                onTap: enabled && files.length < maxItems ? () => _add(context, 'videocam') : null),
          ],
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = files[i];
                final isVideo = StorageService.isVideoPath(f.name.isNotEmpty ? f.name : f.path);
                return Stack(clipBehavior: Clip.none, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: isVideo
                          ? Container(
                              color: AppColors.grape.withValues(alpha: 0.25),
                              child: const Center(
                                child: Icon(Icons.play_circle_fill_rounded,
                                    size: 38, color: AppColors.grape),
                              ),
                            )
                          : FutureBuilder<Uint8List>(
                              future: f.readAsBytes(),
                              builder: (_, snap) => snap.hasData
                                  ? Image.memory(snap.data!, fit: BoxFit.cover)
                                  : Container(color: context.softFill),
                            ),
                    ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: enabled
                          ? () => onChanged(List.of(files)..removeAt(i))
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppColors.coral, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
          const SizedBox(height: 6),
          Text('${files.length}/$maxItems attached',
              style: TextStyle(fontSize: 11, color: context.textSecondary)),
        ],
      ],
    );
  }
}

class _AddChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _AddChip({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

// ─── Gallery (display) ────────────────────────────────────────────────────────

class MediaGallery extends StatelessWidget {
  final List<String> urls;
  final double height;
  const MediaGallery({super.key, required this.urls, this.height = 190});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final url = urls[i];
          final isVideo = StorageService.isVideoUrl(url);
          final w = urls.length == 1 ? MediaQuery.of(context).size.width - 64 : height * 1.25;
          return GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => isVideo
                  ? VideoPlayerPage(url: url)
                  : _PhotoViewer(urls: urls.where((u) => !StorageService.isVideoUrl(u)).toList(), initial: urls.where((u) => !StorageService.isVideoUrl(u)).toList().indexOf(url)),
            )),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: w,
                height: height,
                child: isVideo
                    ? Container(
                        decoration: const BoxDecoration(gradient: AppColors.grapeGradient),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white),
                        ),
                      )
                    : Hero(
                        tag: url,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, p) => p == null
                              ? child
                              : Container(
                                  color: context.softFill,
                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                          errorBuilder: (_, __, ___) => Container(
                            color: context.softFill,
                            child: Icon(Icons.broken_image_outlined, color: context.textSecondary),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  final List<String> urls;
  final int initial;
  const _PhotoViewer({required this.urls, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initial < 0 ? 0 : initial),
        itemCount: urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          child: Center(
            child: Hero(tag: urls[i], child: Image.network(urls[i], fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String url;
  const VideoPlayerPage({super.key, required this.url});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _c;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _ready = true);
          _c.play();
        }
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
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: !_ready
            ? const CircularProgressIndicator()
            : AspectRatio(
                aspectRatio: _c.value.aspectRatio,
                child: Stack(alignment: Alignment.bottomCenter, children: [
                  VideoPlayer(_c),
                  VideoProgressIndicator(_c, allowScrubbing: true),
                ]),
              ),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton(
              onPressed: () => setState(() => _c.value.isPlaying ? _c.pause() : _c.play()),
              child: Icon(_c.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}
