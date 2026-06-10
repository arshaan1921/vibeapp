import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'send_snap_screen.dart';

class _TextOverlay {
  String text;
  Offset position;
  double scale;
  _TextOverlay({required this.text, required this.position, this.scale = 1.0});
}

class EditSnapScreen extends StatefulWidget {
  final String imagePath;
  final bool isVideo;
  final List<double>? filterMatrix;
  const EditSnapScreen({
    super.key, 
    required this.imagePath, 
    this.isVideo = false,
    this.filterMatrix,
  });

  @override
  State<EditSnapScreen> createState() => _EditSnapScreenState();
}

class _EditSnapScreenState extends State<EditSnapScreen> with TickerProviderStateMixin {
  final List<_TextOverlay> _overlays = [];
  _TextOverlay? _editingOverlay;
  bool _isTextMode = false;
  bool _isCapturing = false;
  
  VideoPlayerController? _videoController;
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ScreenshotController _screenshotController = ScreenshotController();

  late AnimationController _uiController;
  late Animation<double> _uiOpacity;
  late Animation<Offset> _pillOffset;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.file(File(widget.imagePath))
        ..initialize().then((_) {
          _videoController!.setLooping(true);
          _videoController!.play();
          setState(() {});
        });
    }
    _uiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _uiOpacity = CurvedAnimation(parent: _uiController, curve: Curves.easeOut);
    _pillOffset = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _uiController, curve: Curves.easeOutCubic));

    _uiController.forward();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _uiController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _sendSnap() async {
    if (widget.isVideo) {
      // For video, we just send the original file for now
      // (Baking overlays into video is more complex)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SendSnapScreen(imagePath: widget.imagePath, isVideo: true),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);
    _textFocusNode.unfocus();
    await Future.delayed(const Duration(milliseconds: 200));
    
    final image = await _screenshotController.capture();
    setState(() => _isCapturing = false);

    if (image != null) {
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/snap_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(imagePath);
      await file.writeAsBytes(image);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SendSnapScreen(imagePath: imagePath, isVideo: false),
          ),
        );
      }
    }
  }

  void _onImageDoubleTap(TapDownDetails details) {
    if (_isTextMode) {
      _finishEditing();
    }
    _addNewOverlay(details.localPosition);
  }

  void _addNewOverlay(Offset position) {
    final newOverlay = _TextOverlay(text: "", position: position);
    setState(() {
      _overlays.add(newOverlay);
      _editingOverlay = newOverlay;
      _textController.text = "";
      _isTextMode = true;
    });
    _textFocusNode.requestFocus();
  }

  void _startEditing(_TextOverlay overlay) {
    setState(() {
      _editingOverlay = overlay;
      _textController.text = overlay.text;
      _isTextMode = true;
    });
    _textFocusNode.requestFocus();
  }

  void _finishEditing() {
    if (_editingOverlay != null) {
      if (_textController.text.trim().isEmpty) {
        setState(() {
          _overlays.remove(_editingOverlay);
        });
      } else {
        setState(() {
          _editingOverlay!.text = _textController.text;
        });
      }
    }
    setState(() {
      _editingOverlay = null;
      _isTextMode = false;
      _textController.clear();
    });
    _textFocusNode.unfocus();
  }

  Widget _buildImageContent() {
    final Widget content = widget.isVideo
        ? (_videoController != null && _videoController!.value.isInitialized
            ? Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            : Container(color: Colors.black))
        : Image.file(
            File(widget.imagePath),
            fit: BoxFit.cover,
          );

    if (widget.filterMatrix != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.matrix(widget.filterMatrix!),
        child: content,
      );
    }
    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. MAIN CANVAS (CAPTURED)
          Screenshot(
            controller: _screenshotController,
            child: GestureDetector(
              onTap: () {
                if (_isTextMode) _finishEditing();
              },
              onDoubleTapDown: _onImageDoubleTap,
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5.0,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: SizedBox.expand(
                        child: _buildImageContent(),
                      ),
                    ),
                    for (final overlay in _overlays)
                      if (overlay != _editingOverlay)
                        _buildDraggableOverlay(overlay),
                  ],
                ),
              ),
            ),
          ),

          // 2. TEXT EDITOR (NON-CAPTURED)
          if (_isTextMode && _editingOverlay != null)
            _buildTextEditorLayer(),

          // 3. MINIMAL UI CONTROLS (NON-CAPTURED)
          if (!_isTextMode && !_isCapturing)
            _buildPremiumUI(),

          // 4. CAPTURING STATE
          if (_isCapturing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableOverlay(_TextOverlay overlay) {
    return Positioned(
      left: 0,
      right: 0,
      top: overlay.position.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {}, // Block single tap from background
        onDoubleTap: () => _startEditing(overlay),
        onDoubleTapDown: (_) {}, // Block double tap down from background
        onVerticalDragUpdate: (details) {
          setState(() {
            overlay.position = Offset(0, overlay.position.dy + details.delta.dy);
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
          color: Colors.black.withOpacity(0.55),
          child: Text(
            overlay.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditorLayer() {
    return Container(
      color: Colors.black.withOpacity(0.3),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          GestureDetector(onTap: _finishEditing, child: Container(color: Colors.transparent)),
          
          // Full-width transparent bar in Editor
          Positioned(
            left: 0,
            right: 0,
            top: _editingOverlay!.position.dy,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 20),
              color: Colors.black.withOpacity(0.55),
              child: TextField(
                controller: _textController,
                focusNode: _textFocusNode,
                autofocus: true,
                maxLines: null,
                textAlign: TextAlign.center,
                cursorColor: Colors.white,
                cursorWidth: 2,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  filled: false,
                ),
                onChanged: (val) => setState(() => _editingOverlay!.text = val),
                onSubmitted: (_) => _finishEditing(),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: TextButton(
              onPressed: _finishEditing,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0),
              ),
              child: const Text("DONE"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumUI() {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return FadeTransition(
      opacity: _uiOpacity,
      child: Stack(
        children: [
          // TOP BAR: Minimal
          Positioned(
            top: topPadding + 10,
            left: 15,
            child: _buildCircularGlassIcon(Icons.close_rounded, () => Navigator.pop(context)),
          ),

          // ADD CAPTION HINT (Only if no overlays yet)
          if (_overlays.isEmpty)
            Positioned(
              bottom: bottomPadding + 30 + 60 + 20, // Positioned above the unified pill
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _addNewOverlay(Offset(0, MediaQuery.of(context).size.height * 0.75)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.text_fields_rounded, color: Colors.white.withOpacity(0.7), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          "Add Caption", 
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7), 
                            fontWeight: FontWeight.w600, 
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // BOTTOM BAR: Unified Pill
          Positioned(
            bottom: bottomPadding + 30,
            left: 20,
            right: 20,
            child: Center(
              child: SlideTransition(
                position: _pillOffset,
                child: ScaleTransition(
                  scale: _uiOpacity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Friends Side
                              GestureDetector(
                                onTap: _sendSnap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  color: Colors.transparent,
                                  child: Row(
                                    children: [
                                      const Text(
                                        "Friends", 
                                        style: TextStyle(
                                          color: Colors.white, 
                                          fontWeight: FontWeight.w800, 
                                          fontSize: 16, 
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withOpacity(0.9), size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Vertical Divider
                              Container(
                                width: 1,
                                height: 24,
                                color: Colors.white.withOpacity(0.15),
                              ),
                              
                              // Send Side
                              GestureDetector(
                                onTap: _sendSnap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  color: Colors.white.withOpacity(0.05),
                                  child: Row(
                                    children: [
                                      const Text(
                                        "Send", 
                                        style: TextStyle(
                                          color: Colors.white, 
                                          fontWeight: FontWeight.w900, 
                                          fontSize: 16, 
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularGlassIcon(IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 0.5),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
      ),
    );
  }
}
