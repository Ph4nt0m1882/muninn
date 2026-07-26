import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:munnin/features/editor/widgets/crow_video_data.dart';

class FlyingCrowAnimation extends StatefulWidget {
  final Offset startPos;
  final Offset endPos;
  final VoidCallback onComplete;

  const FlyingCrowAnimation({
    super.key,
    required this.startPos,
    required this.endPos,
    required this.onComplete,
  });

  /// Utility to show the animation globally
  static void show(
    BuildContext context,
    Offset startPos,
    Offset endPos,
    VoidCallback onComplete,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => FlyingCrowAnimation(
        startPos: startPos,
        endPos: endPos,
        onComplete: () {
          entry.remove();
          onComplete();
        },
      ),
    );

    overlay.insert(entry);
  }

  @override
  State<FlyingCrowAnimation> createState() => _FlyingCrowAnimationState();
}

class _FlyingCrowAnimationState extends State<FlyingCrowAnimation>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  late AnimationController _moveController;
  late Animation<Offset> _positionAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // 2. Initialize Movement Animation
    // The video is 4 seconds. We want 1 second stationary, then 3 seconds of video played in 1 second (3x speed).
    // Total animation time = 2 seconds.
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _moveController.addListener(() {
      if (_videoController != null &&
          _moveController.value >= 0.5 &&
          _videoController!.value.playbackSpeed == 1.0) {
        _videoController!.setPlaybackSpeed(3.0);
      }
    });

    // The crow takes off after 1 second (which is 50% of the 2s animation)
    _positionAnimation =
        Tween<Offset>(begin: widget.startPos, end: widget.endPos).animate(
          CurvedAnimation(
            parent: _moveController,
            curve: const Interval(0.50, 0.95, curve: Curves.easeInOutSine),
          ),
        );

    // Fade out at the very end
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _moveController,
        curve: const Interval(0.95, 1.0, curve: Curves.easeOut),
      ),
    );

    // Shrink slightly as it flies away
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(
        parent: _moveController,
        curve: const Interval(0.50, 0.95, curve: Curves.easeIn),
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}\\flying_crow.dat');
    if (!await file.exists()) {
      await file.writeAsBytes(base64Decode(crowVideoBase64));
    }

    _videoController = VideoPlayerController.file(file);
    await _videoController!.initialize();
    if (!mounted) return;

    setState(() {}); // Update to show video

    // Start video and animation together
    _videoController!.setPlaybackSpeed(1.0);
    _videoController!.play();
    _moveController.forward();

    // Wait for the full 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _moveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // The video is a Black Crow on a White Background.
    // For Light Mode: We want the Black Crow (R=0) to be Opaque (A=255), and White Background (R=255) to be Transparent (A=0).
    // For Dark Mode: We want the White Crow (R=255) to be Opaque (A=255), and Black Background (R=0) to be Transparent (A=0).

    final ColorFilter colorFilter = isDark
        ? const ColorFilter.matrix([
            -1, 0, 0, 0, 255, // R' = 255 - R (Invert to White Crow)
            0, -1, 0, 0, 255, // G' = 255 - G
            0, 0, -1, 0, 255, // B' = 255 - B
            -1,
            0,
            0,
            1,
            0, // A' = A - R (Transparent pixels stay transparent, White bg becomes transparent)
          ])
        : const ColorFilter.matrix([
            0, 0, 0, 0, 0, // R' = 0 (Keep Black Crow)
            0, 0, 0, 0, 0, // G' = 0
            0, 0, 0, 0, 0, // B' = 0
            -1,
            0,
            0,
            1,
            0, // A' = A - R (Transparent pixels stay transparent, White bg becomes transparent)
          ]);

    // Calculate rotation angle to point towards the target
    final dx = widget.endPos.dx - widget.startPos.dx;
    final dy = widget.endPos.dy - widget.startPos.dy;
    // The video crow likely points UP (standard for top-down flight).
    // If it points UP, a movement straight up means 0 rotation.
    // atan2(dy, dx) returns angle from X axis (right).
    // UP is -PI/2. So we need to subtract -PI/2 to align.
    final angle = atan2(dy, dx) + (pi / 2);

    return AnimatedBuilder(
      animation: _moveController,
      builder: (context, child) {
        final pos = _positionAnimation.value;
        return Positioned(
          left: pos.dx - 100, // Offset to center the 200x200 video
          top: pos.dy - 100,
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Transform.rotate(
                  angle: angle,
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: ColorFiltered(
                      colorFilter: colorFilter,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width.clamp(
                            1.0,
                            1000.0,
                          ),
                          height: _videoController!.value.size.height.clamp(
                            1.0,
                            1000.0,
                          ),
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
