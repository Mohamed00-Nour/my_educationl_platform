import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_service.dart';
import '../../domain/entities/lesson_material_entity.dart';

class VideoPlayerScreen extends StatefulWidget {
  final LessonMaterialEntity material;

  const VideoPlayerScreen({
    super.key,
    required this.material,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  WebViewController? _webViewController;

  bool _isYouTube = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  bool _checkIsYouTube(String url) {
    final lower = url.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  String? _extractYouTubeId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    if (uri.host.contains('youtu.be')) {
      return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    }
    if (uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    if (uri.pathSegments.contains('embed')) {
      final idx = uri.pathSegments.indexOf('embed');
      if (idx + 1 < uri.pathSegments.length) {
        return uri.pathSegments[idx + 1];
      }
    }
    if (uri.pathSegments.contains('shorts')) {
      final idx = uri.pathSegments.indexOf('shorts');
      if (idx + 1 < uri.pathSegments.length) {
        return uri.pathSegments[idx + 1];
      }
    }
    return null;
  }

  Future<void> _initPlayer() async {
    final url = widget.material.url.trim();
    if (_checkIsYouTube(url)) {
      setState(() {
        _isYouTube = true;
      });
      _initYouTubePlayer(url);
    } else {
      _initDirectVideo(url);
    }
  }

  void _initYouTubePlayer(String url) {
    final videoId = _extractYouTubeId(url);
    final embedUrl = videoId != null
        ? 'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&playsinline=1&rel=0&modestbranding=1'
        : UrlService.normalizeUrl(url);

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body, html { width: 100%; height: 100%; background-color: #000; display: flex; align-items: center; justify-content: center; overflow: hidden; }
    iframe { width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <iframe src="$embedUrl" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>
</body>
</html>
''';

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'خطأ في تحميل فيديو يوتيوب: ${error.description}';
              });
            }
          },
        ),
      )
      ..loadHtmlString(htmlContent, baseUrl: 'https://www.youtube.com');

    setState(() {
      _webViewController = controller;
    });
  }

  Future<void> _initDirectVideo(String rawUrl) async {
    try {
      final isLocal = !rawUrl.startsWith('http://') && !rawUrl.startsWith('https://') && File(rawUrl).existsSync();

      final videoController = isLocal
          ? VideoPlayerController.file(File(rawUrl))
          : VideoPlayerController.networkUrl(Uri.parse(UrlService.normalizeUrl(rawUrl)));

      _videoPlayerController = videoController;
      await videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: true,
        looping: false,
        aspectRatio: videoController.value.aspectRatio > 0 ? videoController.value.aspectRatio : 16 / 9,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppColors.primary,
          handleColor: AppColors.primary,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تشغيل الفيديو: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.material.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'فتح الرابط الأصلي',
            onPressed: () => UrlService.openExternalUrl(widget.material.url),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 50, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('فتح في مشغل خارجي / يوتيوب'),
                              onPressed: () => UrlService.openExternalUrl(widget.material.url),
                            ),
                          ],
                        ),
                      )
                    : _isLoading
                        ? const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: 16),
                              Text('جاري تهيئة الفيديو...', style: TextStyle(color: Colors.white70)),
                            ],
                          )
                        : _isYouTube
                            ? _webViewController != null
                                ? WebViewWidget(controller: _webViewController!)
                                : const SizedBox.shrink()
                            : _chewieController != null
                                ? Chewie(controller: _chewieController!)
                                : const SizedBox.shrink(),
              ),
            ),
            if (widget.material.notes != null && widget.material.notes!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1E1E1E),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ملاحظات المادة:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.material.notes!,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
