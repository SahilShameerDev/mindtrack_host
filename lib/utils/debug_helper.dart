import 'dart:developer' as developer;

import 'package:flutter/material.dart';

class DebugHelper {
  static const String _tag = "MindTrack";
  
  // Enable or disable verbose logging
  static bool verboseMode = true;
  
  static void log(String message) {
    if (verboseMode) {
      developer.log(message, name: _tag);
    }
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    developer.log(
      "$message: $error",
      name: _tag,
      error: error,
      stackTrace: stackTrace,
    );
  }
  
  static void printBoxContents(String boxName, Map<dynamic, dynamic> contents) {
    developer.log("Contents of $boxName:", name: _tag);
    contents.forEach((key, value) {
      developer.log("  $key: $value", name: _tag);
    });
  }
  
  // Add a method to measure performance
  static Stopwatch startMeasuring(String operation) {
    final stopwatch = Stopwatch()..start();
    log('Starting $operation');
    return stopwatch;
  }
  
  static void endMeasuring(Stopwatch stopwatch, String operation) {
    stopwatch.stop();
    log('Completed $operation in ${stopwatch.elapsedMilliseconds}ms');
  }
  
  // Add a method to print widget tree structure
  static void printWidgetTree(BuildContext context) {
    try {
      final renderObject = context.findRenderObject();
      final renderObjectStr = renderObject.toString();
      log("Widget tree from current context: $renderObjectStr");
    } catch (e) {
      error("Failed to print widget tree", e);
    }
  }
}
