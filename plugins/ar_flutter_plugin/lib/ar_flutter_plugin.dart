export 'package:ar_flutter_plugin/widgets/ar_view.dart';
export 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
export 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
export 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
export 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
export 'package:ar_flutter_plugin/models/ar_anchor.dart';
export 'package:ar_flutter_plugin/models/ar_node.dart';
export 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
export 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
export 'package:ar_flutter_plugin/datatypes/node_types.dart';
export 'package:ar_flutter_plugin/datatypes/anchor_types.dart';
export 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';

import 'dart:async';

import 'package:flutter/services.dart';

class ArFlutterPlugin {
  static const MethodChannel _channel =
      const MethodChannel('ar_flutter_plugin');

  /// Private constructor to prevent accidental instantiation of the Plugin using the implicit default constructor
  ArFlutterPlugin._();

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
