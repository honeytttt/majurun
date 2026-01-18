import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:majurun/core/services/cloudinary_service.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:uuid/uuid.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _controller = TextEditingController();
  final CloudinaryService _cloudinary = CloudinaryService();
  final List<PostMedia> _mediaList = [];
  bool _isUploading = false;

  Future<void> _pickMedia(bool isVideo) async {
    final picker = ImagePicker();
    final XFile? file = isVideo 
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(source: ImageSource.gallery);

    if (file != null) {
      setState(() => _isUploading = true);
      String? url = await _cloudinary.uploadMedia(File(file.path), isVideo);
      
      if (url != null) {
        setState(() {
          _mediaList.add(PostMedia(url: url, type: isVideo ? MediaType.video : MediaType.image));
        });
      }
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Post"),
        actions: [
          if (_isUploading) 
            const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: () {
                // Logic to trigger PostRepositoryImpl().createPost(...)
                Navigator.pop(context);
              },
              child: const Text("POST"),
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              maxLines: null,
              decoration: const InputDecoration(hintText: "What's happening?", contentPadding: EdgeInsets.all(16)),
            ),
          ),
          // Preview Media
          if (_mediaList.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _mediaList.length,
                itemBuilder: (context, i) => Image.network(_mediaList[i].url, width: 100),
              ),
            ),
          // Action Bar
          Row(
            children: [
              IconButton(icon: const Icon(Icons.image), onPressed: () => _pickMedia(false)),
              IconButton(icon: const Icon(Icons.videocam), onPressed: () => _pickMedia(true)),
            ],
          )
        ],
      ),
    );
  }
}