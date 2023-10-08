import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final camers = await availableCameras();
  final fcamers = camers.first;
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Flutter Demo',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    home: MyHomePage(camera: fcamers),
  ));
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.camera});
  final CameraDescription camera;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController _control;
  late Future<void> _initiateControlFU;
  @override
  void initState() {
    super.initState();
    _control = CameraController(
      widget.camera,
      ResolutionPreset.high,
    );
    _initiateControlFU = _control.initialize();
  }

  void disposal() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsFlutterBinding.ensureInitialized();
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("AI Text Scan"),
      ),
      body: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 150),
            child: ClipRRect(
              child: SizedOverflowBox(
                size: const Size(300, 300),
                child: FutureBuilder(
                    future: _initiateControlFU,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done) {
                        return CameraPreview(_control);
                      } else {
                        return const Center(child: CircularProgressIndicator());
                      }
                    }),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        label: const Text('Shutter'),
        icon: const Icon(Icons.camera_alt),
        onPressed: () async {
          await _initiateControlFU;
          final img = await _control.takePicture();
          if (!mounted) return;
          textreco(img.path, context);
        },
      ),
    );
  }

  void textreco(imgPath, context) async {
    final textdic = GoogleMlKit.vision.textRecognizer();
    final image = img.decodeImage(File(imgPath).readAsBytesSync());
    const left = 0;
    const top = 300;
    const width = 700;
    const height = 700;
    final croppedImage = img.copyCrop(image!, left, top, width, height);
    final tempDir = await getTemporaryDirectory();
    final tempImgPath = '${tempDir.path}/cropped_image.jpg';
    File(tempImgPath).writeAsBytesSync(img.encodeJpg(croppedImage));
    final croppedImgs = InputImage.fromFilePath(tempImgPath);
    RecognizedText recotext = await textdic.processImage(croppedImgs);
    await textdic.close();
    var result = '';
    for (TextBlock block in recotext.blocks) {
      for (TextLine line in block.lines) {
        result += '${line.text}\n';
      }
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => DisplayScreen(
                  imgPath: imgPath,
                  resul: result,
                )));
  }
}

class DisplayScreen extends StatelessWidget {
  final String imgPath;
  final String resul;
  const DisplayScreen({super.key, required this.imgPath, required this.resul});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Picture'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(30, 30, 30, 30),
              child: ClipRRect(
                  child: SizedOverflowBox(
                      size: const Size(300, 300),
                      child: Image.file(File(imgPath))))),
          const Text(
            'Output 👇',
            style: TextStyle(
              fontSize: 25,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 9.0, 12.0, 0),
            child: Container(
              height: 300,
              width: 340,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.blueGrey,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: resul.isEmpty
                      ? const Center(
                          heightFactor: 12,
                          child: Text(
                            'Nothing Found',
                            style: TextStyle(
                              fontSize: 17,
                            ),
                          ),
                        )
                      : Text(
                          resul,
                          style: const TextStyle(
                            fontSize: 17,
                          ),
                          textAlign: TextAlign.left,
                        ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
