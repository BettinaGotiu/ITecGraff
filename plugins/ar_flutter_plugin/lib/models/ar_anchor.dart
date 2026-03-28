import 'package:ar_flutter_plugin/datatypes/anchor_types.dart';
import 'package:ar_flutter_plugin/utils/json_converters.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:flutter/widgets.dart';

abstract class ARAnchor {
  ARAnchor({
    required this.type,
    required this.transformation,
    String? name,
  }) : name = name ?? UniqueKey().toString();

  final AnchorType type;
  final String name;

  factory ARAnchor.fromJson(Map<String, dynamic> arguments) {
    final type = arguments['type'];
    switch (type) {
      case 0: //(= AnchorType.plane)
        return ARPlaneAnchor.fromJson(arguments);
      case 1: //(= AnchorType.image)
        return ARImageAnchor.fromJson(arguments);
    }
    return ARUnkownAnchor.fromJson(arguments);
  }

  final Matrix4 transformation;
  Map<String, dynamic> toJson();
}

class ARPlaneAnchor extends ARAnchor {
  ARPlaneAnchor({
    required Matrix4 transformation,
    String? name,
    List<String>? childNodes,
    String? cloudanchorid,
    int? ttl,
  })  : childNodes = childNodes ?? [],
        cloudanchorid = cloudanchorid ?? null,
        ttl = ttl ?? 1,
        super(
            type: AnchorType.plane, transformation: transformation, name: name);

  List<String> childNodes;
  String? cloudanchorid;
  int? ttl;

  static ARPlaneAnchor fromJson(Map<String, dynamic> json) =>
      aRPlaneAnchorFromJson(json);

  @override
  Map<String, dynamic> toJson() => aRPlaneAnchorToJson(this);
}

// ADAUGAT: Clasa pentru ancore bazate pe imagini (postere)
class ARImageAnchor extends ARAnchor {
  ARImageAnchor({
    required Matrix4 transformation,
    required this.referenceImageName,
    required this.physicalSize,
    String? name,
    List<String>? childNodes,
  })  : childNodes = childNodes ?? [],
        super(
            type: AnchorType.image, transformation: transformation, name: name);

  List<String> childNodes;
  String referenceImageName;
  Vector2 physicalSize;

  static ARImageAnchor fromJson(Map<String, dynamic> json) {
    return ARImageAnchor(
      transformation:
          const MatrixConverter().fromJson(json['transformation'] as List),
      name: json['name'] as String,
      referenceImageName: json['referenceImageName'] as String? ?? '',
      physicalSize: Vector2(
        (json['physicalWidth'] as num?)?.toDouble() ?? 0.0,
        (json['physicalHeight'] as num?)?.toDouble() ?? 0.0,
      ),
      childNodes: json['childNodes']
          ?.map((child) => child.toString())
          ?.toList()
          ?.cast<String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.index,
      'transformation': MatrixConverter().toJson(transformation),
      'name': name,
      'referenceImageName': referenceImageName,
      'physicalWidth': physicalSize.x,
      'physicalHeight': physicalSize.y,
      'childNodes': childNodes,
    };
  }
}

ARPlaneAnchor aRPlaneAnchorFromJson(Map<String, dynamic> json) {
  return ARPlaneAnchor(
    transformation:
        const MatrixConverter().fromJson(json['transformation'] as List),
    name: json['name'] as String,
    childNodes: json['childNodes']
        ?.map((child) => child.toString())
        ?.toList()
        ?.cast<String>(),
    cloudanchorid: json['cloudanchorid'] as String?,
    ttl: json['ttl'] as int?,
  );
}

Map<String, dynamic> aRPlaneAnchorToJson(ARPlaneAnchor instance) {
  return <String, dynamic>{
    'type': instance.type.index,
    'transformation': MatrixConverter().toJson(instance.transformation),
    'name': instance.name,
    'childNodes': instance.childNodes,
    'cloudanchorid': instance.cloudanchorid,
    'ttl': instance.ttl,
  };
}

class ARUnkownAnchor extends ARAnchor {
  ARUnkownAnchor(
      {required AnchorType type, required Matrix4 transformation, String? name})
      : super(type: type, transformation: transformation, name: name);

  static ARUnkownAnchor fromJson(Map<String, dynamic> json) =>
      aRUnkownAnchorFromJson(json);

  @override
  Map<String, dynamic> toJson() => aRUnkownAnchorToJson(this);
}

ARUnkownAnchor aRUnkownAnchorFromJson(Map<String, dynamic> json) {
  return ARUnkownAnchor(
    type: json['type'],
    transformation:
        const MatrixConverter().fromJson(json['transformation'] as List),
    name: json['name'] as String,
  );
}

Map<String, dynamic> aRUnkownAnchorToJson(ARUnkownAnchor instance) {
  return <String, dynamic>{
    'type': instance.type.index,
    'transformation': MatrixConverter().toJson(instance.transformation),
    'name': instance.name,
  };
}
