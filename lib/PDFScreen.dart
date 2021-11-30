

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';

class PDFScreen extends StatefulWidget {
  final String path;

  PDFScreen({required Key? key, required this.path}) : super(key: key);

  _PDFScreenState createState() => _PDFScreenState();
}

class _PDFScreenState extends State<PDFScreen> with WidgetsBindingObserver {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.share,
                color: Colors.white,
              ),
              onPressed: () => _onShare(context)
            )
          ],
          title: Text("Invoice"),
        ),
        body: Container(
            child: SfPdfViewer.file(
                File(widget.path))));
  }

  void _onShare(BuildContext context) async {

    final box = context.findRenderObject() as RenderBox?;

      await Share.shareFiles([widget.path],
          text: 'Send  via email',
          subject: 'Invoice',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size);

  }
}