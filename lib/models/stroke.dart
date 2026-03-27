import 'dart:ui';

class Stroke {
  Stroke({
    required this.id,
    required this.points,
    required this.color,
    required this.width,
    required this.userId,
  });

  final String id;
  final List<Offset> points;
  final int color;
  final double width;
  final String userId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'pts': points.map((point) => [point.dx, point.dy]).toList(),
        'color': color,
        'w': width,
        'u': userId,
      };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
        id: json['id'] as String,
        points: (json['pts'] as List<dynamic>)
            .map((point) => Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()))
            .toList(),
        color: json['color'] as int,
        width: (json['w'] as num).toDouble(),
        userId: json['u'] as String,
      );
}
