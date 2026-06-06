import 'dart:io';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'send_snap_screen.dart';

class EditSnapScreen extends StatefulWidget {
  final String imagePath;
  const EditSnapScreen({super.key, required this.imagePath});

  @override
  State<EditSnapScreen> createState() => _EditSnapScreenState();
}

class _EditSnapScreenState extends State<EditSnapScreen> {
  late String _currentPath;
  String? _captionText;
  Offset _captionPosition = Offset.zero;
  bool _isTextMode = false;
  
  final TextEditingController _textController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
  }

  Future<void> _saveAndContinue() async {
    final image = await _screenshotController.capture();
    if (image != null) {
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/edited_snap_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(imagePath);
      await file.writeAsBytes(image);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SendSnapScreen(imagePath: imagePath),
          ),
        );
      }
    }
  }

  void _startEditingText() {
    if (_captionPosition == Offset.zero) {
      _captionPosition = Offset(0, MediaQuery.of(context).size.height * 0.45);
    }
    setState(() {
      _isTextMode = true;
      _textController.text = _captionText ?? "";
    });
  }

  void _finishEditingText() {
    setState(() {
      _captionText = _textController.text.trim().isEmpty ? null : _textController.text;
      _isTextMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      appBar: _isTextMode ? null : AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_fields, color: Colors.white),
            onPressed: _startEditingText,
          ),
          TextButton(
            onPressed: _saveAndContinue,
            child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Canvas
          Screenshot(
            controller: _screenshotController,
            child: Container(
              color: Colors.black,
              width: double.infinity,
              height: double.infinity,
              child: Stack(
                children: [
                  // Image
                  Center(
                    child: Image.file(File(_currentPath), fit: BoxFit.contain),
                  ),

                  // Snapchat Style Caption Strip
                  if (_captionText != null)
                    _buildCaption(),
                ],
              ),
            ),
          ),

          // Text Input Overlay
          if (_isTextMode)
            _buildTextEditOverlay(),
        ],
      ),
    );
  }

  Widget _buildCaption() {
    return Positioned(
      left: 0,
      right: 0,
      top: _captionPosition.dy,
      child: GestureDetector(
        onTap: _startEditingText,
        onVerticalDragUpdate: (details) {
          setState(() {
            _captionPosition = Offset(0, _captionPosition.dy + details.delta.dy);
          });
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: Colors.black.withOpacity(0.5),
          child: Text(
            _captionText!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextEditOverlay() {
    return Stack(
      children: [
        // Semi-transparent background dimming
        GestureDetector(
          onTap: _finishEditingText,
          child: Container(
            color: Colors.black45,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // Caption bar while editing (exactly like Snapchat)
        Positioned(
          left: 0,
          right: 0,
          top: _captionPosition.dy,
          child: Container(
            width: double.infinity,
            color: Colors.black.withOpacity(0.5),
            child: TextField(
              controller: _textController,
              autofocus: true,
              maxLines: null,
              textAlign: TextAlign.center,
              cursorColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "",
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => _finishEditingText(),
            ),
          ),
        ),

        // Top bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _isTextMode = false),
                  ),
                  TextButton(
                    onPressed: _finishEditingText,
                    child: const Text("Done", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
