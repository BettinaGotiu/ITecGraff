import 'package:flutter/material.dart';

class ToolbarWidget extends StatelessWidget {
  final String currentColor;
  final double currentBrushSize;
  final bool isEraser;
  final Function(String) onColorSelected;
  final Function(double) onBrushSizeChanged;
  final VoidCallback onEraserToggled;

  const ToolbarWidget({
    Key? key,
    required this.currentColor,
    required this.currentBrushSize,
    required this.isEraser,
    required this.onColorSelected,
    required this.onBrushSizeChanged,
    required this.onEraserToggled,
  }) : super(key: key);

  final List<String> colors = const [
    "#FF4081", // Pink
    "#2196F3", // Blue
    "#4CAF50", // Green
    "#FFEB3B", // Yellow
    "#FF9800", // Orange
    "#000000", // Black
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Colors and Eraser
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...colors.map((colorHex) {
                  bool isSelected = currentColor == colorHex && !isEraser;
                  Color c = Color(
                    int.parse("0xFF${colorHex.replaceAll('#', '')}"),
                  );
                  return GestureDetector(
                    onTap: () => onColorSelected(colorHex),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  );
                }).toList(),

                // Eraser Button
                GestureDetector(
                  onTap: onEraserToggled,
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isEraser ? Colors.black : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: const Icon(Icons.cleaning_services, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Brush Size Slider
          Row(
            children: [
              const Icon(Icons.brush, size: 16, color: Colors.grey),
              Expanded(
                child: Slider(
                  value: currentBrushSize,
                  min: 2.0,
                  max: 20.0,
                  activeColor: isEraser
                      ? Colors.grey
                      : Color(
                          int.parse("0xFF${currentColor.replaceAll('#', '')}"),
                        ),
                  onChanged: onBrushSizeChanged,
                ),
              ),
              const Icon(Icons.brush, size: 24, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}
