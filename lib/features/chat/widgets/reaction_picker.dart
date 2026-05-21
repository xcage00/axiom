import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class ReactionPicker extends StatelessWidget {
  final Function(String) onReactionSelected;
  
  const ReactionPicker({
    super.key,
    required this.onReactionSelected,
  });

  final List<Map<String, dynamic>> reactions = const [
    {'emoji': '❤️', 'name': 'Love'},
    {'emoji': '👍', 'name': 'Like'},
    {'emoji': '😂', 'name': 'Haha'},
    {'emoji': '😮', 'name': 'Wow'},
    {'emoji': '😢', 'name': 'Sad'},
    {'emoji': '😡', 'name': 'Angry'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AxiomColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.map((reaction) {
          return GestureDetector(
            onTap: () => onReactionSelected(reaction['emoji']),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reaction['emoji'],
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reaction['name'],
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AxiomColors.darkTextSecondary : AxiomColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}