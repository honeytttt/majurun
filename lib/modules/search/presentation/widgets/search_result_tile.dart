import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:majurun/core/services/search_service.dart';

class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _buildLeading(),
      title: Text(
        result.title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        result.subtitle,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 13,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _buildTrailingIcon(),
    );
  }

  Widget _buildLeading() {
    if (result.type == 'user') {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.grey[200],
        backgroundImage: result.imageUrl != null && result.imageUrl!.isNotEmpty
            ? CachedNetworkImageProvider(result.imageUrl!)
            : null,
        child: result.imageUrl == null || result.imageUrl!.isEmpty
            ? Icon(Icons.person, color: Colors.grey.shade700)
            : null,
      );
    } else {
      // Post result
      if (result.imageUrl != null && result.imageUrl!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: result.imageUrl!,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 48,
              height: 48,
              color: Colors.grey[200],
              child: const Icon(Icons.image, color: Colors.grey),
            ),
            errorWidget: (context, url, error) => Container(
              width: 48,
              height: 48,
              color: Colors.grey[200],
              child: const Icon(Icons.article, color: Colors.grey),
            ),
          ),
        );
      }
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.article, color: Colors.grey.shade700),
      );
    }
  }

  Widget _buildTrailingIcon() {
    return Icon(
      result.type == 'user' ? Icons.person_outline : Icons.article_outlined,
      color: Colors.grey.shade700,
      size: 20,
    );
  }
}
