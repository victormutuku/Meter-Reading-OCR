import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_utils.dart';

class ImageClassificationHelper {
  static const modelPath = 'assets/best-fp16.tflite';

  late final Interpreter interpreter;
  final List<String> labels = ['meter reading'];
  late Tensor inputTensor;
  late Tensor outputTensor;

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
    // Set tensor output [1, 1001]
    // final outputData = [List<int>.filled(outputTensor.shape[1], 0)];
    final outputData = List.generate(
      1,
      (_) => List.generate(
        25200,
        (_) => List<double>.filled(6, 0),
      ),
    );

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

      // // Get first output tensor
      // final result = outputData.first;
      // int maxScore = result.reduce((a, b) => a + b);

      // // Set classification map {label: points}
      // var classification = <String, double>{};
      // for (var i = 0; i < result.length; i++) {
      //   if (result[i] != 0) {
      //     // Set label: points
      //     classification[labels[i]] = result[i].toDouble() / maxScore.toDouble();
      //   }
      // }
    }
    return processedDetections;
  }

  // inference camera frame
  Future<List<Map<String, dynamic>>> inferenceCameraFrame(CameraImage cameraImage) async {
    return inference(cameraImage);
  }

  // inference still image
  Future<List<Map<String, dynamic>>> inferenceImage(image_lib.Image image) async {
    return inference(image);
  }

  void close() {
    interpreter.close();
  }
}
