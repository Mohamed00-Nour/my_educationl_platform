import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/url_service.dart';
import '../../domain/entities/lesson_material_entity.dart';

class PdfViewerScreen extends StatefulWidget {
  final LessonMaterialEntity material;

  const PdfViewerScreen({
    super.key,
    required this.material,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerStateKey = GlobalKey();

  int _currentPage = 1;
  int _pageCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pdfViewerController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  bool get _isLocalFile {
    final url = widget.material.url.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return false;
    }
    final file = File(url);
    return file.existsSync();
  }

  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('انتقال إلى صفحة'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'رقم الصفحة (1 - $_pageCount)',
            labelText: 'رقم الصفحة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final target = int.tryParse(controller.text.trim());
              if (target != null && target >= 1 && target <= _pageCount) {
                _pdfViewerController.jumpToPage(target);
                Navigator.pop(ctx);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPageRange = widget.material.startPage != null;
    String rangeText = '';
    if (hasPageRange) {
      if (widget.material.endPage != null && widget.material.endPage != widget.material.startPage) {
        rangeText = 'الصفحات المقررة: ${widget.material.startPage} - ${widget.material.endPage}';
      } else {
        rangeText = 'صفحة الدرس: ${widget.material.startPage}';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.material.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_pageCount > 0)
              Text(
                'صفحة $_currentPage من $_pageCount',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
          ],
        ),
        actions: [
          if (_pageCount > 0)
            IconButton(
              icon: const Icon(Icons.pin_outlined),
              tooltip: 'انتقال لصفحة',
              onPressed: _showJumpToPageDialog,
            ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'تكبير',
            onPressed: () => _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel + 0.25).clamp(1.0, 3.0),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'تصغير',
            onPressed: () => _pdfViewerController.zoomLevel = (_pdfViewerController.zoomLevel - 0.25).clamp(1.0, 3.0),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'فتح في تطبيق خارجي',
            onPressed: () => UrlService.openExternalUrl(widget.material.url),
          ),
        ],
      ),
      body: Column(
        children: [
          if (hasPageRange)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withAlpha(30),
              child: Row(
                children: [
                  const Icon(Icons.bookmark_outline, size: 18, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Text(
                    rangeText,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                  ),
                  const Spacer(),
                  if (widget.material.startPage != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _pdfViewerController.jumpToPage(widget.material.startPage!),
                      child: const Text('انتقل للبداية', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
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
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('فتح في متصفح / تطبيق خارجي'),
                            onPressed: () => UrlService.openExternalUrl(widget.material.url),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _isLocalFile
                      ? SfPdfViewer.file(
                          File(widget.material.url.trim()),
                          key: _pdfViewerStateKey,
                          controller: _pdfViewerController,
                          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                            setState(() {
                              _isLoading = false;
                              _pageCount = details.document.pages.count;
                            });
                            if (widget.material.startPage != null && widget.material.startPage! > 0) {
                              _pdfViewerController.jumpToPage(widget.material.startPage!);
                            }
                          },
                          onPageChanged: (PdfPageChangedDetails details) {
                            setState(() => _currentPage = details.newPageNumber);
                          },
                          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                            setState(() {
                              _isLoading = false;
                              _errorMessage = 'تعذر تحميل ملف PDF: ${details.description}';
                            });
                          },
                        )
                      : SfPdfViewer.network(
                          UrlService.normalizeUrl(widget.material.url),
                          key: _pdfViewerStateKey,
                          controller: _pdfViewerController,
                          onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                            setState(() {
                              _isLoading = false;
                              _pageCount = details.document.pages.count;
                            });
                            if (widget.material.startPage != null && widget.material.startPage! > 0) {
                              _pdfViewerController.jumpToPage(widget.material.startPage!);
                            }
                          },
                          onPageChanged: (PdfPageChangedDetails details) {
                            setState(() => _currentPage = details.newPageNumber);
                          },
                          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                            setState(() {
                              _isLoading = false;
                              _errorMessage = 'تعذر تحميل ملف PDF من الرابط: ${details.description}';
                            });
                          },
                        ),
                if (_isLoading && _errorMessage == null)
                  Container(
                    color: AppColors.background.withAlpha(180),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('جاري تحميل المستند...', style: TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
