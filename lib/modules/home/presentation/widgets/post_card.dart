import 'package:flutter/material.dart';

class PostCard extends StatelessWidget {
  final String username;
  final String content;
  final String imageUrl;

  const PostCard({
    super.key,
    required this.username,
    required this.content,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      elevation: 0,
      shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFFEEEEEE))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.more_horiz)),
          ),
          
          // Post Image (Placeholder)
          Container(
            height: 300,
            width: double.infinity,
            color: Colors.grey[200],
            child: const Icon(Icons.image, size: 50, color: Colors.grey),
          ),

          // Interaction Bar
          Row(
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.chat_bubble_outline)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
              const Spacer(),
              IconButton(onPressed: () {}, icon: const Icon(Icons.bookmark_border)),
            ],
          ),

          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(text: "$username ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: content),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}