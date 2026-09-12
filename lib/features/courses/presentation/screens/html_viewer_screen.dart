import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_service.dart';
import '../../domain/entities/lesson_material_entity.dart';

class HtmlViewerScreen extends StatefulWidget {
  final LessonMaterialEntity material;

  const HtmlViewerScreen({
    super.key,
    required this.material,
  });

  @override
  State<HtmlViewerScreen> createState() => _HtmlViewerScreenState();
}

class _HtmlViewerScreenState extends State<HtmlViewerScreen> {
  late final WebViewController _controller;
  double _progress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'حدث خطأ أثناء تحميل الصفحة: ${error.description}';
              });
            }
          },
        ),
      );

    _loadContent();
  }

  Future<void> _loadContent() async {
    final rawUrl = widget.material.url.trim();

    try {
      final isLocal = !rawUrl.startsWith('http://') && !rawUrl.startsWith('https://') && File(rawUrl).existsSync();

      if (isLocal) {
        final file = File(rawUrl);
        final htmlContent = await file.readAsString();
        await _controller.loadHtmlString(htmlContent, baseUrl: file.parent.uri.toString());
      } else {
        final normalized = UrlService.normalizeUrl(rawUrl);
        await _controller.loadRequest(Uri.parse(normalized));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر قراءة ملف HTML: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.material.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة تحميل',
            onPressed: () => _loadContent(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'فتح خارجياً',
            onPressed: () => UrlService.openExternalUrl(widget.material.url),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3.0),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('إعادة المحاولة'),
                      onPressed: () => _loadContent(),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('فتح في متصفح خارجي'),
                      onPressed: () => UrlService.openExternalUrl(widget.material.url),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
        ],
      ),
    );
  }
}
