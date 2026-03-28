import 'dart:ui';

class DrawPoint {
  final double x;
  final double y;
  final double brushSize;
  final String color;

  DrawPoint({
    required this.x,
    required this.y,
    required this.brushSize,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'brushSize': brushSize,
        'color': color,
      };

  factory DrawPoint.fromJson(Map<String, dynamic> json) => DrawPoint(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        brushSize: (json['brushSize'] as num).toDouble(),
        color: json['color'] as String,
      );
}

class StrokeBatch {
  final String posterId;
  final String userId;
  final String teamId;
  final List<DrawPoint> strokes;

  StrokeBatch({
    required this.posterId,
    required this.userId,
    required this.teamId,
    required this.strokes,
  });

  Map<String, dynamic> toJson() => {
        'posterId': posterId,
        'userId': userId,
        'teamId': teamId,
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  factory StrokeBatch.fromJson(Map<String, dynamic> json) => StrokeBatch(
        posterId: json['posterId'] ?? '',
        userId: json['userId'] ?? '',
        teamId: json['teamId'] ?? '',
        strokes: (json['strokes'] as List<dynamic>?)
                ?.map((e) => DrawPoint.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
