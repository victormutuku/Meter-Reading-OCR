/*
 * Copyright 2023 The TensorFlow Authors. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *             http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:meter_reading_ocr/utils/colors.dart';
import '../utils/new_model_class.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  ImageClassificationHelper? imageClassificationHelper;
  final imagePicker = ImagePicker();
  String? imagePath;
  img.Image? image;
  List<Map<String, dynamic>>? classification;
  bool cameraIsAvailable = Platform.isAndroid || Platform.isIOS;
  Map<String, int> pixelCoords = {
    'x': 0,
    'y': 0,
    'width': 0,
    'height': 0,
  };
  List<Map<String, int>> pCds = [
    {
      'x': 0,
      'y': 0,
      'width': 0,
      'height': 0,
    }
  ];
  List<String> labelList = [''];
  late double confidenceLevel;
  late List<double> highestBboxList;

  @override
  void initState() {
    imageClassificationHelper = ImageClassificationHelper();
    imageClassificationHelper!.initHelper();
    confidenceLevel = imageClassificationHelper!.highestConfidence;
    highestBboxList = imageClassificationHelper!.highestConfidenceBBox;
    super.initState();
  }

  // Clean old results when press some take picture button
  void cleanResult() {
    imagePath = null;
    image = null;
    classification = null;
    pixelCoords = {
      'x': 0,
      'y': 0,
      'width': 0,
      'height': 0,
    };
    imageClassificationHelper!.highestConfidence = -1.0;
    imageClassificationHelper!.highestConfidenceBBox = [];
    setState(() {});
  }

  // Process picked image
  Future<void> processImage() async {
    if (imagePath != null) {
      // Read image bytes from file
      final imageData = File(imagePath!).readAsBytesSync();

      // Decode image using package:image/image.dart (https://pub.dev/image)
      image = img.decodeImage(imageData);
      setState(() {});
      classification = await imageClassificationHelper?.inferenceImage(image!);
      pixelCoords = imageClassificationHelper!.normalizedToPixelCoords(image!.width, image!.height);
      pCds = imageClassificationHelper!.nPC(image!.width, image!.height);
      labelList = imageClassificationHelper!.labelList();
      setState(() {});
    }
  }

  @override
  void dispose() {
    imageClassificationHelper?.close();
    super.dispose();
  }

  List<Widget> bboxes = [];

  void createBboxes() {
    for (var i = 0; i < pCds.length; i++) {
      bboxes.add(
        Positioned(
          left: pCds[i]['x']!.toDouble(),
          top: pCds[i]['y']!.toDouble(),
          width: pCds[i]['width']!.toDouble(),
          height: pCds[i]['height']!.toDouble(),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.red,
                width: 2,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // createBboxes();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meter Reading OCR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: primaryColor,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (imagePath != null) Image.file(File(imagePath!)),
          if (image == null)
            const Center(
              child: Text("Choose one from the gallery to inference"),
            ),
          // Stack(children: bboxes),
          Positioned(
            left: pixelCoords['x']!.toDouble(),
            top: pixelCoords['y']!.toDouble(),
            width: pixelCoords['width']!.toDouble(),
            height: pixelCoords['height']!.toDouble(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
              ),
            ),
          ),
          // Text(classification!.toString()),
          Padding(
            padding: const EdgeInsets.only(top: 400, left: 40, right: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                imageClassificationHelper!.highestConfidence != -1.0
                    ? Text('Highest Confidence: ${imageClassificationHelper!.highestConfidence}')
                    : const SizedBox(),
                const SizedBox(height: 10),
                imageClassificationHelper!.highestConfidenceBBox.isNotEmpty
                    ? Text('Best bbox: ${imageClassificationHelper!.highestConfidenceBBox}')
                    : const SizedBox(),
              ],
            ),
          ),

          // Padding(
          //   padding: const EdgeInsets.only(
          //     top: 400,
          //     left: 40,
          //     right: 40,
          //   ),
          //   child: Text(
          //     labelList.join(),
          //   ),
          // ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          cleanResult();
          final result = await imagePicker.pickImage(
            source: ImageSource.gallery,
          );

          imagePath = result?.path;
          setState(() {});
          processImage();
        },
        foregroundColor: Colors.white,
        backgroundColor: primaryColor,
        child: const Icon(Icons.image),
      ),
    );
    // return SafeArea(
    //   child: Column(
    //     children: [
    //       Row(
    //         mainAxisAlignment: MainAxisAlignment.spaceAround,
    //         children: [
    //           if (cameraIsAvailable)
    //             TextButton.icon(
    //               onPressed: () async {
    //                 cleanResult();
    //                 final result = await imagePicker.pickImage(
    //                   source: ImageSource.camera,
    //                 );

    //                 imagePath = result?.path;
    //                 setState(() {});
    //                 processImage();
    //               },
    //               icon: const Icon(
    //                 Icons.camera,
    //                 size: 48,
    //               ),
    //               label: const Text("Take a photo"),
    //               style: TextButton.styleFrom(foregroundColor: primaryColor),
    //             ),
    //           TextButton.icon(
    //             onPressed: () async {
    //               cleanResult();
    //               final result = await imagePicker.pickImage(
    //                 source: ImageSource.gallery,
    //               );

    //               imagePath = result?.path;
    //               setState(() {});
    //               processImage();
    //             },
    //             icon: const Icon(
    //               Icons.photo,
    //               size: 48,
    //             ),
    //             label: const Text("Pick from gallery"),
    //             style: TextButton.styleFrom(foregroundColor: primaryColor),
    //           ),
    //         ],
    //       ),
    //       const Divider(color: Colors.black),
    //       Expanded(
    //         child:
    //         Stack(
    //           alignment: Alignment.topCenter,
    //           children: [
    //             if (imagePath != null) Image.file(File(imagePath!)),
    //             if (image == null)
    //               const Text("Take a photo or choose one from the gallery to "
    //                   "inference."),
    //             // Positioned(
    //             //   left: pixelCoords['x']!.toDouble(),
    //             //   top: pixelCoords['y']!.toDouble(),
    //             //   width: pixelCoords['width']!.toDouble(),
    //             //   height: pixelCoords['height']!.toDouble(),
    //             //   child: Container(
    //             //     decoration: BoxDecoration(
    //             //       border: Border.all(color: Colors.red, width: 2),
    //             //     ),
    //             //   ),
    //             // ),
    //             Stack(children: bboxes),
    //             // Column(
    //             //   crossAxisAlignment: CrossAxisAlignment.start,
    //             //   children: [
    //             //     const Row(),
    //             //     if (image != null) ...[
    //             //       // Show model information
    //             //       if (imageClassificationHelper?.inputTensor != null)
    //             //         Text(
    //             //           'Input: (shape: ${imageClassificationHelper?.inputTensor.shape} type: '
    //             //           '${imageClassificationHelper?.inputTensor.type})',
    //             //         ),
    //             //       if (imageClassificationHelper?.outputTensor != null)
    //             //         Text(
    //             //           'Output: (shape: ${imageClassificationHelper?.outputTensor.shape} '
    //             //           'type: ${imageClassificationHelper?.outputTensor.type})',
    //             //         ),
    //             //       const SizedBox(height: 8),
    //             //       // Show picked image information
    //             //       Text('Num channels: ${image?.numChannels}'),
    //             //       Text('Bits per channel: ${image?.bitsPerChannel}'),
    //             //       Text('Height: ${image?.height}'),
    //             //       Text('Width: ${image?.width}'),
    //             //     ],
    //             //     const Spacer(),
    //             //     // Show classification result
    //             //     SingleChildScrollView(
    //             //       child: classification != null
    //             //           ? Column(
    //             //               children: [
    //             //                 Column(
    //             //                     children: classification!.map((e) {
    //             //                   log(classification.toString());
    //             //                   return Text(e.toString());
    //             //                 }).toList()),
    //             //                 const Divider(),
    //             //                 Text(classification!.toString()),
    //             //                 // Text(
    //             //                 //     'Highest Confidence: ${imageClassificationHelper!.highestConfidence}'),
    //             //                 // const SizedBox(height: 20),
    //             //                 // Text(
    //             //                 //     'Best bbox: ${imageClassificationHelper!.highestConfidenceBBox}'),
    //             //               ],
    //             //             )
    //             //           : const Text("No Values"),
    //             //     ),
    //             //   ],
    //             // ),
    //           ],
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}
