import 'package:flutter/material.dart';

class RecentSearchesList extends StatelessWidget {
  final List<String> searches;
  final Function(String) onSearchTap;
  final Function(String) onRemove;
  final VoidCallback onClearAll;

  const RecentSearchesList({
    super.key,
    required this.searches,
    required this.onSearchTap,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (searches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Search for users or posts',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: onClearAll,
                child: const Text(
                  'Clear All',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searches.length,
            itemBuilder: (context, index) {
              final search = searches[index];
              return ListTile(
                onTap: () => onSearchTap(search),
                leading: Icon(
                  Icons.history,
                  color: Colors.grey[400],
                ),
                title: Text(
                  search,
                  style: const TextStyle(fontSize: 15),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: () => onRemove(search),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
