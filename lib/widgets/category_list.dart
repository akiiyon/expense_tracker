import 'package:flutter/material.dart';

class CategoryList extends StatefulWidget {
  final Function(String) onCategorySelected; // ✅ callback to parent

  const CategoryList({super.key, required this.onCategorySelected});
  @override
  _CategoryListState createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  String? selectedCategory;

  final List<String> _categories = [
    "Rent",
    "Bill",
    "Food",
    "Grocery",
    "Entertainment",
    "Other"
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._categories.map((category) {
          bool isSelected = selectedCategory == category;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                selectedCategory = selected ? category : null;
              });
              if (selected) {
                widget.onCategorySelected(category); // ✅ send to parent
              }
            },
          );
        }).toList(),
      ],
    );
  }
}
