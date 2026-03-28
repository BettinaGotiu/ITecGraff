import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../managers/ar_session_manager.dart';
import '../managers/ar_object_manager.dart';
import '../managers/ar_anchor_manager.dart';
import '../managers/ar_location_manager.dart';
import '../datatypes/config_planedetection.dart';

typedef ARViewCreatedCallback = void Function(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager);

class ARView extends StatefulWidget {
  final ARViewCreatedCallback onARViewCreated;
  final bool showPlanes;
  final bool customPlaneTexturePath;
  final bool showFeaturePoints;
  final bool showWorldOrigin;
  final bool handleTaps;
  final bool handlePans;
  final bool handleRotation;
  final PlaneDetectionConfig planeDetectionConfig;

  const ARView({
    Key? key,
    required this.onARViewCreated,
    this.showPlanes = false,
    this.customPlaneTexturePath = false,
    this.showFeaturePoints = false,
    this.showWorldOrigin = false,
    this.handleTaps = true,
    this.handlePans = true,
    this.handleRotation = true,
    this.planeDetectionConfig = PlaneDetectionConfig.none,
  }) : super(key: key);

  @override
  _ARViewState createState() => _ARViewState();
}

class _ARViewState extends State<ARView> {
  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        viewType: 'ar_flutter_plugin',
        onPlatformViewCreated: onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'ar_flutter_plugin',
        onPlatformViewCreated: onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return Text('$defaultTargetPlatform is not supported by this plugin');
  }

  void onPlatformViewCreated(int id) {
    // REZOLVAT: Am pasat argumentele corecte si complete catre fiecare manager in parte
    widget.onARViewCreated(
      ARSessionManager(id, context, widget.planeDetectionConfig), // 3 argumente
      ARObjectManager(id), // 1 argument
      ARAnchorManager(id), // 1 argument
      ARLocationManager(), // 0 argumente
    );
  }
}
