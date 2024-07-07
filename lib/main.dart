import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

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

  @override
  void initState() {
    getConfiguration = getConfigurations();
    super.initState();
  }

  double percentageDifference(int value1, int value2) {
    int difference = (value1 - value2).abs();
    double percentageDifference = (difference / value1) * 100;
    return percentageDifference;
  }

  double removePercentage(double value, double percentage) {
    double amountToRemove = (value * percentage) / 100;
    return value - amountToRemove;
  }

  Future<List<Config>> getConfigurations() async {
    String data = await DefaultAssetBundle.of(context).loadString("assets/config.json");
    final jsonResult = jsonDecode(data)["config"] as List;
    return jsonResult.map((element) => Config.fromMap(element)).toList();
  }

  void setAnnotations(PdfDocument document, List<Config> configurations) {
    for (var config in configurations) {
      var sentences = config.chunk!.replaceAll('\n', ' ');
      var lines = PdfTextExtractor(document).extractTextLines(startPageIndex: config.pageNumber);
      for (var line in lines) {
        if (sentences.contains(line.text)) {
          controller.addAnnotation(
              HighlightAnnotation(textBoundsCollection: [PdfTextLine(line.bounds, line.text, line.pageIndex + 1)]));
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
            return SfPdfViewer.network(
              "http://ianswer-public-web-bucket.s3-website.us-east-2.amazonaws.com/assets/136.pdf",
              controller: controller,
              onDocumentLoaded: (details) {
                document = details.document;
                setAnnotations(details.document, snapshot.data!);
              },
            );
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

  factory Config.fromJson(String source) => Config.fromMap(json.decode(source) as Map<String, dynamic>);
}
