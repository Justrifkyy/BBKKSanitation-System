import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

class InteractivePhotoViewer extends StatefulWidget {
  const InteractivePhotoViewer({
    super.key,
    required this.imageUrl,
    this.title = 'Foto Bukti Pemeriksaan',
    this.subtitle,
    this.latitude,
    this.longitude,
    this.timestamp,
  });

  final String imageUrl;
  final String title;
  final String? subtitle;
  final double? latitude;
  final double? longitude;
  final DateTime? timestamp;

  static void show(
    BuildContext context, {
    required String imageUrl,
    String title = 'Foto Bukti Pemeriksaan',
    String? subtitle,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, __) => InteractivePhotoViewer(
          imageUrl: imageUrl,
          title: title,
          subtitle: subtitle,
          latitude: latitude,
          longitude: longitude,
          timestamp: timestamp,
        ),
      ),
    );
  }

  @override
  State<InteractivePhotoViewer> createState() => _InteractivePhotoViewerState();
}

class _InteractivePhotoViewerState extends State<InteractivePhotoViewer> {
  final TransformationController _transformController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _isDownloading = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      // ignore: deprecated_member_use
      _transformController.value = Matrix4.identity()
        // ignore: deprecated_member_use
        ..translate(-position.dx * 1.5, -position.dy * 1.5)
        // ignore: deprecated_member_use
        ..scale(2.5);
    }
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final uri = Uri.parse(widget.imageUrl);
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException('Gagal mengunduh berkas (${response.statusCode})');
      }

      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      final timestampStr = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ARJUNA_BUKTI_$timestampStr.jpg';

      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      if (saveDir == null) {
        throw const FileSystemException('Folder penyimpanan tidak ditemukan');
      }

      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto berhasil disimpan ke: ${file.path}'),
          backgroundColor: SiskaraTheme.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh foto: $e'),
          backgroundColor: SiskaraTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Zoomable Image
            Center(
              child: GestureDetector(
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 5.0,
                  child: Image.network(
                    widget.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, _) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white54, size: 64),
                          SizedBox(height: 12),
                          Text(
                            'Gagal memuat foto',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top Control Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Kembali',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded, color: Colors.white),
                      onPressed: _isDownloading ? null : _downloadImage,
                      tooltip: 'Unduh foto ke perangkat',
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Info Bar (GPS & Timestamp)
            if (widget.latitude != null || widget.timestamp != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.latitude != null && widget.longitude != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              'GPS: ${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (widget.timestamp != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text(
                              'Waktu Foto: ${widget.timestamp!.toLocal()}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
