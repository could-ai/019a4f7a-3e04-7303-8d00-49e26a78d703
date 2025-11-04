import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image to Video Converter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  List<XFile> _selectedImages = [];
  String? _outputVideoPath;
  bool _isGenerating = false;
  VideoPlayerController? _videoController;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        _selectedImages = images;
      });
    }
  }

  Future<void> _generateVideo() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final inputDir = Directory('${directory.path}/input');
      await inputDir.create(recursive: true);

      // Copy selected images to input directory with numbered names
      for (int i = 0; i < _selectedImages.length; i++) {
        final imageFile = File(_selectedImages[i].path);
        final newPath = '${inputDir.path}/image_${(i + 1).toString().padLeft(4, '0')}.jpg';
        await imageFile.copy(newPath);
      }

      // Generate output video path
      _outputVideoPath = '${directory.path}/output_video.mp4';

      // FFmpeg command to create video from images
      final command = '-framerate 1 -i ${inputDir.path}/image_%04d.jpg -c:v libx264 -pix_fmt yuv420p $_outputVideoPath';

      final result = await _flutterFFmpeg.execute(command);
      if (result == 0) {
        // Success
        _initializeVideoPlayer();
      } else {
        // Error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate video')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _initializeVideoPlayer() {
    if (_outputVideoPath != null) {
      _videoController = VideoPlayerController.file(File(_outputVideoPath!))
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to Video Converter'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _pickImages,
              child: const Text('Pick Images'),
            ),
            const SizedBox(height: 16),
            if (_selectedImages.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Image.file(
                      File(_selectedImages[index].path),
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            if (_selectedImages.isNotEmpty)
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateVideo,
                child: _isGenerating
                    ? const CircularProgressIndicator()
                    : const Text('Generate Video'),
              ),
            const SizedBox(height: 16),
            if (_videoController != null && _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            if (_videoController != null && _videoController!.value.isInitialized)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      });
                    },
                    icon: Icon(
                      _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}