import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'Search_provider.dart';

final searchProvider = StateProvider<String>((ref) => '');

class SearchAndFilter extends ConsumerWidget {
  const SearchAndFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController =
        TextEditingController(text: ref.watch(searchProvider));

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 2,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    ref.read(searchQueryProvider.notifier).state = value;
                    if (value.isEmpty) {
                      ref.read(searchProvider.notifier).state = '';
                    }
                  },
                  decoration: InputDecoration(
                    suffixIcon: GestureDetector(
                      onTap: () {
                        searchController.text.trim();
                      },
                      child: const Icon(
                        Icons.search_sharp,
                        color: Color(0xFF273847),
                        size: 30,
                      ),
                    ),
                    hintText: "Search for products",
                    hintStyle: TextStyle(
                      color: Color(0xFF273847),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
