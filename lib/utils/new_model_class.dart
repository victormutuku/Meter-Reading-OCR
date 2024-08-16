import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_utils.dart';

class ImageClassificationHelper {
  static const modelPath = 'assets/best-fp16.tflite';
  // static const modelPath = 'assets/best-fp16-tony.tflite';

  late final Interpreter interpreter;
  final List<String> labels = ['meter reading'];
  // final List<String> labels = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  late Tensor inputTensor;
  late Tensor outputTensor;

  late List<Map<String, dynamic>> bboxAndConfidenceList;

  // Variables to store the highest confidence and corresponding bbox
  double highestConfidence = -1.0;
  List<double> highestConfidenceBBox = [];

  // Load model
  Future<void> _loadModel() async {
    final options = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      options.addDelegate(XNNPackDelegate());
    }

    // Use Metal Delegate
    if (Platform.isIOS) {
      options.addDelegate(GpuDelegate());
    }

    // Load model from assets
    interpreter = await Interpreter.fromAsset(modelPath, options: options);
    // Get tensor input shape [1, 224, 224, 3]
    inputTensor = interpreter.getInputTensors().first;
    // Get tensor output shape [1, 1001]
    outputTensor = interpreter.getOutputTensors().first;

    log('Interpreter loaded successfully');
  }

  Future<void> initHelper() async {
    await _loadModel();
  }

  Future<List<Map<String, dynamic>>> inference(dynamic input) async {
    image_lib.Image? img;
    if (input is CameraImage) {
      img = ImageUtils.convertCameraImage(input);
    } else if (input is image_lib.Image) {
      img = input;
    } else {
      throw ArgumentError('Input must be CameraImage or image_lib.Image');
    }

    // resize original image to match model shape.
    image_lib.Image imageInput = image_lib.copyResize(
      img!,
      width: inputTensor.shape[1],
      height: inputTensor.shape[2],
    );

    if (Platform.isAndroid && input is CameraImage) {
      imageInput = image_lib.copyRotate(imageInput, angle: 90);
    }

    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        },
      ),
    );

    // Set tensor input [1, 224, 224, 3]
    final inputData = [imageMatrix];

    final outputData = List.generate(
      1,
      (_) => List.generate(
        25200,
        (_) => List<double>.filled(6, 0),
      ),
    );

    // final outputData = List.generate(
    //   1,
    //   (_) => List.generate(
    //     10647,
    //     (_) => List<double>.filled(17, 0),
    //   ),
    // );

    // Run inference
    interpreter.run(inputData, outputData);

    // Get first output tensor
    final detections = outputData[0];

    // Process detections
    List<Map<String, dynamic>> processedDetections = [];
    for (var detection in detections) {
      double confidence = detection[4];

      // Apply a confidence threshold (e.g., 0.5)
      if (confidence > 0.5) {
        double x = detection[0];
        double y = detection[1];
        double w = detection[2];
        double h = detection[3];
        // int classIndex = detection[5].round();

        processedDetections.add({
          'bbox': [x, y, w, h],
          'confidence': confidence,
          'class': labels[0],
        });
      }
    }
    return processedDetections;
  }

  // inference camera frame
  Future<List<Map<String, dynamic>>> inferenceCameraFrame(CameraImage cameraImage) async {
    return inference(cameraImage);
  }

  // inference still image
  Future<List<Map<String, dynamic>>> inferenceImage(image_lib.Image image) async {
    return inference(image).then((value) {
      log(value.toString());
      bboxAndConfidenceList = value;
      extractValues();
      return [];
    });
  }

  void extractValues() {
    if (bboxAndConfidenceList.isEmpty) {
      highestConfidence = 0.0;
      highestConfidenceBBox = [];
      return;
    }

    if (bboxAndConfidenceList.length == 1) {
      // If the list has only one item, assign its values directly
      highestConfidence = bboxAndConfidenceList[0]['confidence'];
      highestConfidenceBBox = List<double>.from(bboxAndConfidenceList[0]['bbox']);
    } else {
      // Iterate through the list to find the highest confidence
      for (var item in bboxAndConfidenceList) {
        double confidence = item['confidence'];
        if (confidence > highestConfidence) {
          highestConfidence = confidence;
          highestConfidenceBBox = List<double>.from(item['bbox']);
        }
      }
    }
  }

  // void extractValues() {
  //   for (var detection in bboxAndConfidenceList) {
  //     double confidence = detection['confidence'];
  //     if (confidence > highestConfidence) {
  //       highestConfidence = confidence;
  //       highestConfidenceBBox = List<double>.from(detection['bbox']);
  //     }
  //   }
  // }

  Map<String, int> normalizedToPixelCoords(int imageWidth, int imageHeight) {
    // bbox format is [x_center, y_center, width, height]
    final xCenter = highestConfidenceBBox[0] * imageWidth;
    final yCenter = highestConfidenceBBox[1] * imageHeight;
    final width = highestConfidenceBBox[2] * imageWidth;
    final height = highestConfidenceBBox[3] * imageHeight;

    return {
      'x': (xCenter - width / 2).round(),
      'y': (yCenter - height / 2).round(),
      'width': width.round(),
      'height': height.round(),
    };
  }

  List<Map<String, int>> nPC(int imageWidth, int imageHeight) {
    List<Map<String, int>> list = [];

    for (var bbox in bboxAndConfidenceList) {
      dynamic bboxList = bbox['bbox'];
      Map<String, int> mapbbox = {};

      final xCenter = bboxList[0] * imageWidth;
      final yCenter = bboxList[1] * imageHeight;
      final width = bboxList[2] * imageWidth;
      final height = bboxList[3] * imageHeight;

      mapbbox = {
        'x': (xCenter - width / 2).round(),
        'y': (yCenter - height / 2).round(),
        'width': width.round(),
        'height': height.round(),
      };
      list.add(mapbbox);
    }

    return list;
  }

  List<String> labelList() {
    List<String> lList = [];
    for (var labels in bboxAndConfidenceList) {
      String label = labels['class'];
      lList.add(label);
    }
    return lList;
  }

  String determineApproximatePosition(Rect boundingBox, int imageWidth, int imageHeight) {
    // Calculate bounding box center point
    double centerX = boundingBox.left + boundingBox.width / 2;
    double centerY = boundingBox.top + boundingBox.height / 2;

    // Tolerance for "In-Front" based on bounding box size and image size
    double toleranceX = boundingBox.width * 0.1; // 40% of bounding box width
    double toleranceY = boundingBox.height * 0.1; // 40% of bounding box height

    // Check if center point is close enough to image center (considering tolerances)
    if (centerX.abs() < imageWidth / 2 + toleranceX &&
        centerY.abs() < imageHeight / 2 + toleranceY) {
      return "In-Front";
    }

    bool isTopHalf = boundingBox.top < imageHeight / 2;
    bool isLeftHalf = boundingBox.left < imageWidth / 2;

    // Determine approximate position based on quadrant and half
    if (isTopHalf) {
      if (isLeftHalf) {
        return "Front-Left";
      } else {
        return "Front-Right";
      }
    } else {
      if (isLeftHalf) {
        return "Behind-Left";
      } else {
        return "Behind-Right";
      }
    }
  }

  void close() {
    interpreter.close();
  }
}
