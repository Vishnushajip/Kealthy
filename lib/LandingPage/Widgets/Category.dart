import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../DetailsPage/SubCategory.dart';

class Category {
  final String name;
  final String imageUrl;

  Category({required this.name, required this.imageUrl});

  factory Category.fromFirestore(Map<String, dynamic> data) {
    return Category(
      name: data['Categories'] as String,
      imageUrl: data['imageurl'] as String,
    );
  }
}

class CategoryItem extends StatelessWidget {
  final String categoryName;
  final String imageUrl;

  const CategoryItem({
    super.key,
    required this.categoryName,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoodCategoriesScreen(
              category: categoryName,
            ),
          ),
        );
      },
      child: Column(
        children: [
          CachedNetworkImage(
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            imageUrl: imageUrl,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                color: Colors.grey[300],
                width: screenWidth * 0.25,
                height: screenWidth * 0.25,
              ),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
          ),
          const SizedBox(height: 5),
          Text(
            categoryName.replaceAll(r'\n', '\n'),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                color: Colors.grey[300],
                width: screenWidth * 0.25,
                height: screenWidth * 0.25,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No categories found"));
        }

        final categories = snapshot.data!.docs
            .map((doc) => Category.fromFirestore(doc.data()))
            .toList();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.2),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryItem(
              categoryName: category.name,
              imageUrl: category.imageUrl,
            );
          },
        );
      },
    );
  }
}
