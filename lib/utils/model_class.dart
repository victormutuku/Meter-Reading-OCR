// import 'dart:math';

import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

late Interpreter interpreter;
late List<int> _inputShape;
late List<int> _outputShape;
late TfLiteType _inputType;
late TfLiteType _outputType;

// late TensorImage _inputImage;

final List<String> labels = ['meter readings'];

// NormalizeOp preProcessNormalizeOp;
// NormalizeOp get postProcessNormalizeOp;

void loadModel() async {
  try {
    interpreter = await Interpreter.fromAsset('assets/best-fp16.tflite');
    _inputShape = interpreter.getInputTensor(0).shape;
    _outputShape = interpreter.getOutputTensor(0).shape;
    _inputType = interpreter.getInputTensor(0).type as TfLiteType;
    _outputType = interpreter.getOutputTensor(0).type as TfLiteType;
  } catch (e) {
    debugPrint('Unable to create interpreter. Exception: ${e.toString()}');
  }
}

// TensorImage _preProcess() {
//     int cropSize = min(_inputImage.height, _inputImage.width);
//     return ImageProcessorBuilder()
//         .add(ResizeWithCropOrPadOp(cropSize, cropSize))
//         .add(ResizeOp(
//             _inputShape[1], _inputShape[2], ResizeMethod.nearestneighbour))
//         .add(preProcessNormalizeOp)
//         .build()
//         .process(_inputImage);
//   }
