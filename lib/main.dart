import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  PdfViewerController controller = PdfViewerController();
  late Future<List<Config>> getConfiguration;
  late List<Config> configuration;
  late PdfDocument document;
  late Future<Uint8List> loadPdf;

  bool isloading = true;

  @override
  void initState() {
    getConfiguration =
        getConfigurations().then((value) => configuration = value);
    loadPdf = loadPFD();
    super.initState();
  }

  Future<List<Config>> getConfigurations() async {
    String data =
        await DefaultAssetBundle.of(context).loadString("assets/config.json");
    final jsonResult = jsonDecode(data) as List;
    return jsonResult.map((element) => Config.fromMap(element)).toList();
  }

  Future<Uint8List> loadPFD() async {
    return await http.readBytes(Uri.parse(
        "http://ianswer-public-web-bucket.s3-website.us-east-2.amazonaws.com/assets/136.pdf"));
  }

  void setAnnotations(PdfDocument document, List<Config> configurations) async {
    for (var config in configurations) {
      var sentences = config.chunk!.replaceAll('\r\n', ' ');

      var lines = PdfTextExtractor(document)
          .extractTextLines(startPageIndex: config.pageNumber! - 1);
      for (var line in lines) {
        if (sentences.similarTo(line.text)) {
          controller.addAnnotation(HighlightAnnotation(textBoundsCollection: [
            PdfTextLine(line.bounds, line.text, line.pageIndex + 1)
          ]));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.on_device_training),
          onPressed: () {
            setAnnotations(document, configuration);
          },
        ),
      ),
      body: FutureBuilder(
        future: getConfiguration,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          } else if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          } else {
            configuration = snapshot.data!;
            return FutureBuilder(
                future: loadPdf,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snap.hasError) {
                    return Center(child: Text(snap.error.toString()));
                  } else {
                    if (snap.data != null) {
                      return SfPdfViewer.memory(
                        snap.data!,
                        controller: controller,
                        onDocumentLoaded: (details) {
                          setState(() {
                            isloading = false;
                          });
                          document = details.document;
                          setAnnotations(details.document, snapshot.data!);
                        },
                      );
                    }

                    return const Center(
                      child: Text("Data is empty"),
                    );
                  }
                });
          }
        },
      ),
    );
  }
}

class Config {
  Config({
    this.filename,
    this.chunk,
    this.pageNumber,
    this.startIndex,
    this.endIndex,
  });

  String? filename;
  String? chunk;
  int? pageNumber;
  int? startIndex;
  int? endIndex;

  factory Config.fromMap(Map<String, dynamic> map) {
    return Config(
      filename: map['file_name'] != null ? map['file_name'] as String : null,
      chunk: map['chunk'] != null ? map['chunk'] as String : null,
      pageNumber: map['page_number'] != null ? map['page_number'] as int : null,
      startIndex: map['start_index'] != null ? map['start_index'] as int : null,
      endIndex: map['end_index'] != null ? map['end_index'] as int : null,
    );
  }

  factory Config.fromJson(String source) =>
      Config.fromMap(json.decode(source) as Map<String, dynamic>);
}

extension StringSimilarity on String {
  bool similarTo(String other) {
    for (int i = 0; i <= length - other.length; i++) {
      String substring = this.substring(i, i + other.length);
      double similarity = _calculateSimilarity(substring, other);
      // Accepts similarity upto 90%
      if (similarity >= 0.9) {
        return true;
      }
    }
    return false;
  }

  double _calculateSimilarity(String s1, String s2) {
    int length = s1.length;
    int matches = 0;

    for (int i = 0; i < length; i++) {
      if (s1[i] == s2[i]) {
        matches++;
      }
    }

    return matches / length;
  }
}
