import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:otakulink/core/cache/local_cache_service.dart';
import '../providers/reading_mode_provider.dart';

class ReaderImageItem extends StatefulWidget {
  final String imageUrl;
  final ReadingMode mode;
  final void Function(TapUpDetails) onTapUp;
  final ValueChanged<bool>? onZoomChanged;

  const ReaderImageItem({
    super.key,
    required this.imageUrl,
    required this.mode,
    required this.onTapUp,
    this.onZoomChanged,
  });

  @override
  State<ReaderImageItem> createState() => _ReaderImageItemState();
}

class _ReaderImageItemState extends State<ReaderImageItem>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();
  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  bool _isCurrentlyZoomed = false;

  @override
  void initState() {
    super.initState();

    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformController.value = _zoomAnimation!.value;
        }
      });

    _transformController.addListener(() {
      final isZoomed = _transformController.value.getMaxScaleOnAxis() > 1.05;
      if (isZoomed != _isCurrentlyZoomed) {
        _isCurrentlyZoomed = isZoomed;
        widget.onZoomChanged?.call(isZoomed);
      }
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    if (widget.mode == ReadingMode.vertical || _doubleTapDetails == null)
      return;

    final Matrix4 currentMatrix = _transformController.value;
    final double currentScale = currentMatrix.getMaxScaleOnAxis();

    final double targetScale = currentScale > 1.05 ? 1.0 : 2.5;
    final Matrix4 targetMatrix = Matrix4.identity();

    if (targetScale > 1.0) {
      final Offset tapPosition = _doubleTapDetails!.localPosition;
      targetMatrix
        ..translate(tapPosition.dx, tapPosition.dy)
        ..scale(targetScale)
        ..translate(-tapPosition.dx, -tapPosition.dy);
    }

    _zoomAnimation = Matrix4Tween(
      begin: currentMatrix,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeOutQuart,
    ));

    _zoomAnimationController.forward(from: 0);
  }

  int _getCacheWidth(BuildContext context) {
    return (MediaQuery.of(context).size.width *
            MediaQuery.of(context).devicePixelRatio)
        .round();
  }

  @override
  Widget build(BuildContext context) {
    final cacheWidth = _getCacheWidth(context);

    final rawImage = CachedNetworkImage(
      cacheManager: LocalCacheService.pagesCache,
      imageUrl: widget.imageUrl,
      memCacheWidth: cacheWidth,
      httpHeaders: const {
        'User-Agent': 'OtakuLink/1.0 (otakulink.dev@gmail.com)'
      },
      fit: BoxFit.fitWidth,
      placeholder: (context, url) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child:
            Center(child: CircularProgressIndicator(color: Colors.grey[800])),
      ),
      errorWidget: (context, url, error) => const SizedBox(
        height: 300,
        child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      ),
    );

    if (widget.mode == ReadingMode.vertical) {
      return GestureDetector(
        onTapUp: widget.onTapUp,
        child: rawImage,
      );
    }

    return GestureDetector(
      onTapUp: widget.onTapUp,
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: true,
        scaleEnabled: true,
        child: rawImage,
      ),
    );
  }
}
