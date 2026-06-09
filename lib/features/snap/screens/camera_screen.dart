import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../models/camera_filter.dart';
import 'edit_snap_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isReady = false;
  int _selectedCameraIndex = 0;
  
  // New States
  int _flashModeIndex = 0; // 0: off, 1: auto, 2: always
  final List<FlashMode> _flashModes = [FlashMode.off, FlashMode.auto, FlashMode.always];
  
  double _currentZoom = 1.0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _baseZoom = 1.0;
  bool _showZoomIndicator = false;
  Timer? _zoomIndicatorTimer;

  Offset? _focusPoint;
  bool _showFocusSquare = false;
  Timer? _focusTimer;

  bool _showUI = false;

  // Filter state
  int _activeFilterIndex = 0;
  final PageController _filterPageController = PageController(viewportFraction: 0.25);
  final ScreenshotController _screenshotController = ScreenshotController();

  late AnimationController _shutterController;
  late Animation<double> _shutterScale;
  late Animation<double> _ringScale;
  late Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    
    _shutterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _shutterScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _shutterController, curve: Curves.easeInOut),
    );

    _ringScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _shutterController, curve: Curves.easeOutCubic),
    );

    _glowOpacity = Tween<double>(begin: 0.0, end: 0.4).animate(
      CurvedAnimation(parent: _shutterController, curve: Curves.easeInOut),
    );
    
    // Entrance animation trigger
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _showUI = true);
    });
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![_selectedCameraIndex],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      try {
        await _controller!.initialize();
        
        _minAvailableZoom = await _controller!.getMinZoomLevel();
        _maxAvailableZoom = await _controller!.getMaxZoomLevel();
        
        // Ensure flash mode is set to current state
        await _controller!.setFlashMode(_flashModes[_flashModeIndex]);

        if (mounted) {
          setState(() => _isReady = true);
        }
      } catch (e) {
        debugPrint('Camera initialization error: $e');
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _filterPageController.dispose();
    _zoomIndicatorTimer?.cancel();
    _focusTimer?.cancel();
    _shutterController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    HapticFeedback.lightImpact();
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    
    setState(() {
      _isReady = false;
      _currentZoom = 1.0;
    });
    
    await _controller?.dispose();
    _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    
    _flashModeIndex = (_flashModeIndex + 1) % _flashModes.length;
    await _controller!.setFlashMode(_flashModes[_flashModeIndex]);
    
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void _onFilterChanged(int index) {
    if (_activeFilterIndex != index) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _activeFilterIndex = index;
    });
  }

  Future<void> _handleFocus(TapUpDetails details, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final x = details.localPosition.dx / constraints.maxWidth;
    final y = details.localPosition.dy / constraints.maxHeight;
    final point = Offset(x, y);

    try {
      setState(() {
        _focusPoint = details.localPosition;
        _showFocusSquare = true;
      });

      await _controller!.setFocusPoint(point);
      await _controller!.setExposurePoint(point);

      _focusTimer?.cancel();
      _focusTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _showFocusSquare = false);
      });
    } catch (e) {
      debugPrint('Focus error: $e');
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized || _cameras![_selectedCameraIndex].lensDirection == CameraLensDirection.front) {
      return;
    }

    double zoom = (_baseZoom * details.scale).clamp(_minAvailableZoom, _maxAvailableZoom);
    
    if (zoom != _currentZoom) {
      _currentZoom = zoom;
      await _controller!.setZoomLevel(_currentZoom);
      
      setState(() {
        _showZoomIndicator = true;
      });

      _zoomIndicatorTimer?.cancel();
      _zoomIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showZoomIndicator = false);
      });
    }
  }

  Future<void> _handleZoomButton(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    double targetZoom = zoom.clamp(_minAvailableZoom, _maxAvailableZoom);
    if (targetZoom != _currentZoom) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentZoom = targetZoom;
        _showZoomIndicator = true;
      });
      await _controller!.setZoomLevel(_currentZoom);
      
      _zoomIndicatorTimer?.cancel();
      _zoomIndicatorTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showZoomIndicator = false);
      });
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    HapticFeedback.mediumImpact();

    try {
      // 1. Instant Hardware Capture
      final XFile rawImage = await _controller!.takePicture();

      if (mounted) {
        // 2. Navigate immediately to EditSnapScreen with the filter matrix
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditSnapScreen(
              imagePath: rawImage.path,
              filterMatrix: CameraFilter.filters[_activeFilterIndex].matrix,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditSnapScreen(imagePath: image.path),
        ),
      );
    }
  }

  IconData _getFlashIcon() {
    switch (_flashModes[_flashModeIndex]) {
      case FlashMode.off: return Icons.flash_off_rounded;
      case FlashMode.auto: return Icons.flash_auto_rounded;
      case FlashMode.always: return Icons.flash_on_rounded;
      default: return Icons.flash_off_rounded;
    }
  }

  Color _getFilterAccentColor(String name) {
    switch (name) {
      case "Warm": return Colors.orangeAccent;
      case "Cool": return Colors.lightBlueAccent;
      case "Vintage": return Colors.brown;
      case "B&W": return Colors.grey;
      case "Vibrant": return Colors.pinkAccent;
      default: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final filters = CameraFilter.filters;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera Preview with Live Filter & Gestures
              GestureDetector(
                onDoubleTap: _flipCamera,
                onTapUp: (details) => _handleFocus(details, constraints),
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! < 0) {
                    // Swipe Left -> Next
                    if (_activeFilterIndex < filters.length - 1) {
                      _filterPageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  } else if (details.primaryVelocity! > 0) {
                    // Swipe Right -> Previous
                    if (_activeFilterIndex > 0) {
                      _filterPageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                },
                child: Screenshot(
                  controller: _screenshotController,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(filters[_activeFilterIndex].matrix),
                    child: CameraPreview(_controller!),
                  ),
                ),
              ),

              // 2. Focus Square Animation
              if (_showFocusSquare && _focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 35,
                  top: _focusPoint!.dy - 35,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.0, end: 0.0),
                    duration: const Duration(seconds: 1),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.yellow, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // 3. Zoom Indicator & Quick Controls
              Positioned(
                bottom: 220,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showUI ? 1.0 : 0.0,
                  child: Column(
                    children: [
                      if (_showZoomIndicator)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${_currentZoom.toStringAsFixed(1)}x",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildZoomButton(0.5),
                          const SizedBox(width: 12),
                          _buildZoomButton(1.0),
                          const SizedBox(width: 12),
                          _buildZoomButton(2.0),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 4. UI Overlays
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // Top Row: Flash & Flip (Redesigned)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showUI ? 1.0 : 0.0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 300),
                          offset: _showUI ? Offset.zero : const Offset(0, -0.5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _buildTopButton(
                                icon: _getFlashIcon(),
                                onPressed: _toggleFlash,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Filter Selector (Redesigned with Glassmorphism)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showUI ? 1.0 : 0.0,
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 300),
                          offset: _showUI ? Offset.zero : const Offset(0, 0.5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                                ),
                                height: 110,
                                child: PageView.builder(
                                  controller: _filterPageController,
                                  onPageChanged: _onFilterChanged,
                                  itemCount: filters.length,
                                  itemBuilder: (context, index) {
                                    final isSelected = _activeFilterIndex == index;
                                    final accentColor = _getFilterAccentColor(filters[index].name);
                                    
                                    return AnimatedScale(
                                      scale: isSelected ? 1.2 : 0.85,
                                      duration: const Duration(milliseconds: 200),
                                      child: Opacity(
                                        opacity: isSelected ? 1.0 : 0.6,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: () {
                                                _filterPageController.animateToPage(
                                                  index,
                                                  duration: const Duration(milliseconds: 300),
                                                  curve: Curves.easeInOut,
                                                );
                                              },
                                              child: Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: accentColor.withOpacity(0.4),
                                                  border: Border.all(
                                                    color: isSelected ? Colors.white : Colors.white38,
                                                    width: isSelected ? 2.5 : 1,
                                                  ),
                                                  boxShadow: isSelected ? [
                                                    BoxShadow(
                                                      color: Colors.white.withOpacity(0.3),
                                                      blurRadius: 10,
                                                      spreadRadius: 1,
                                                    )
                                                  ] : null,
                                                ),
                                                child: Center(
                                                  child: Container(
                                                    width: 14,
                                                    height: 14,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: isSelected ? Colors.white : accentColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              filters[index].name,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.white60,
                                                fontSize: 11,
                                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Bottom Dock Redesign
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _showUI ? 1.0 : 0.0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Gallery Button
                            _buildBottomActionButton(
                              icon: Icons.photo_library_rounded,
                              onPressed: _pickFromGallery,
                            ),
                            
                            // Shutter Button (Redesigned)
                            AnimatedScale(
                              duration: const Duration(milliseconds: 300),
                              scale: _showUI ? 1.0 : 0.9,
                              child: _buildShutterButton(),
                            ),
                            
                            // Flip Button
                            _buildBottomActionButton(
                              icon: Icons.cached_rounded,
                              onPressed: _flipCamera,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBottomActionButton({required IconData icon, required VoidCallback onPressed}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildZoomButton(double zoom) {
    bool available = zoom >= _minAvailableZoom && zoom <= _maxAvailableZoom;
    if (!available && zoom != 1.0) return const SizedBox.shrink();
    
    final isSelected = _currentZoom == zoom || (_currentZoom < zoom + 0.1 && _currentZoom > zoom - 0.1);
    return GestureDetector(
      onTap: available ? () => _handleZoomButton(zoom) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.5),
          boxShadow: isSelected ? [
            BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)
          ] : null,
        ),
        child: Center(
          child: Text(
            "${zoom % 1 == 0 ? zoom.toInt() : zoom}x",
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.heavyImpact();
        _shutterController.forward();
      },
      onLongPressEnd: (_) {
        _shutterController.reverse();
      },
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _shutterController.forward().then((_) => _shutterController.reverse());
      },
      onTap: _takePicture,
      child: AnimatedBuilder(
        animation: _shutterController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer Glow
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(_glowOpacity.value),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
              // Expanding Ring
              Transform.scale(
                scale: _ringScale.value,
                child: Container(
                  width: 85,
                  height: 85,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(1.0 - _shutterController.value),
                      width: 2,
                    ),
                  ),
                ),
              ),
              // Main Shutter
              Transform.scale(
                scale: _shutterScale.value,
                child: Container(
                  width: 80,
                  height: 80,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
