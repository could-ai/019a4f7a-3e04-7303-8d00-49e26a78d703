import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:io';

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
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
  // For iOS, you need to add the following to your Info.plist file:
  // <key>NSPhotoLibraryAddUsageDescription</key>
  // <string>This app needs access to your photo library to save videos.</string>

  final ImagePicker _picker = ImagePicker();
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg();
  List<XFile> _selectedImages = [];
  String? _outputVideoPath;
  bool _isGenerating = false;
  bool _isSaving = false;
  VideoPlayerController? _videoController;

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages = images;
        _outputVideoPath = null;
        _videoController?.dispose();
        _videoController = null;
      });
    }
  }

  Future<void> _generateVideo() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isGenerating = true;
    });

    Directory? inputDir;
    try {
      final directory = await getApplicationDocumentsDirectory();
      inputDir = Directory('${directory.path}/input');
      if (await inputDir.exists()) {
        await inputDir.delete(recursive: true);
      }
      await inputDir.create(recursive: true);

      for (int i = 0; i < _selectedImages.length; i++) {
        final imageFile = File(_selectedImages[i].path);
        final newPath =
            '${inputDir.path}/image_${(i + 1).toString().padLeft(4, '0')}.jpg';
        await imageFile.copy(newPath);
      }

      _outputVideoPath = '${directory.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp4';
      if (File(_outputVideoPath!).existsSync()) {
        await File(_outputVideoPath!).delete();
      }
      
      final command = '-framerate 1 -i ${inputDir.path}/image_%04d.jpg -c:v libx264 -r 30 -pix_fmt yuv420p $_outputVideoPath';

      final result = await _flutterFFmpeg.execute(command);
      if (result == 0) {
        _initializeVideoPlayer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate video. Please try again.')),
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
      if (inputDir != null && await inputDir.exists()) {
        await inputDir.delete(recursive: true);
      }
    }
  }

  void _initializeVideoPlayer() {
    if (_outputVideoPath != null) {
      _videoController = VideoPlayerController.file(File(_outputVideoPath!))
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
          _videoController?.setLooping(true);
        });
    }
  }

  Future<void> _saveVideo() async {
    if (_outputVideoPath == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final bool? success = await GallerySaver.saveVideo(_outputVideoPath!);
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video saved to gallery!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save video.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving video: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
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
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image),
              label: const Text('Pick Images'),
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
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.file(
                        File(_selectedImages[index].path),
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            if (_selectedImages.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateVideo,
                icon: const Icon(Icons.movie),
                label: _isGenerating
                    ? const Text('Generating...')
                    : const Text('Generate Video'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            if (_isGenerating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            const SizedBox(height: 16),
            if (_videoController != null && _videoController!.value.isInitialized)
              Expanded(
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                    const SizedBox(height: 8),
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
                            _videoController!.value.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveVideo,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_alt),
                          label: const Text('Save to Gallery'),
                        ),
                      ],
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
