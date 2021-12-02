

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rayshio_invoicer/helpers/ObjectBox.dart';
import 'package:rayshio_invoicer/models/Invoice.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'main.dart';
import 'objectbox.g.dart';

class PDFScreen extends StatefulWidget {
  final String path;
  String label;
  int invoiceId;
  Box invoiceBox;
  late Invoice _currentInvoice;

  PDFScreen({required Key? key, required this.path, required this.invoiceId,
  required this.label, required this.invoiceBox}) :
        super(key: key) {


    // get the invoice from db
    _currentInvoice = invoiceBox.get(invoiceId);
  }

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
                File(widget.path))),
    floatingActionButton:
    Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(padding: EdgeInsets.only(right: 75),
          child: new Visibility(
              visible: !widget._currentInvoice.paid,
              child: FloatingActionButton(
                onPressed: markPaid,
                tooltip: 'Mark Paid',
                child: Icon(
                  Icons.money,
                  size: 30,
                ),
              ))),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child:  new Visibility(
              visible: true,
              child: FloatingActionButton(
                onPressed: _showConfirmationDialog,
                tooltip: 'Delete Invoice',
                child: Icon(
                  Icons.delete,
                  size: 30,
                ),
              )),
        ),
      ],
    )
    // FloatingActionButton(
    //   onPressed: deleteInvoice,
    //   tooltip: 'delete Invoice',
    //   child: Icon(
    //     Icons.delete,
    //     size: 30,
    //   ),
    // ),
    );
  }

  void _onShare(BuildContext context) async {

    final box = context.findRenderObject() as RenderBox?;

      await Share.shareFiles([widget.path],
          text: 'Send  via email',
          subject: 'Invoice',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size);

  }

  Future<void> _showConfirmationDialog() async {

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Invoice?', style: TextStyle
            (fontSize: 24) ),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Row(children: [Text('Are you sure ?')]),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                print('Confirmed');
                Navigator.of(context).pop();
                deleteInvoice();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

    Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    print('path ${widget.path}');
    return File(widget.path);
  }

  Future<void> deleteInvoice() async {
    try {
      final file = await _localFile;
      setState(() async {
        await file.delete();
        widget.invoiceBox.remove(widget.invoiceId);

        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => MyHomePage(key: widget.key,
              title: 'Raysh.io LLC')),
        );
      });
    } catch (e) {

    }
  }

  Future<Uint8List> _readDocumentData(path) async{
    return await File(widget.path).readAsBytes();
  }

  Future<void> _addWatermarkToPDF() async {
    //Load the PDF document.
    PdfDocument documents =
    PdfDocument(inputBytes: await _readDocumentData(widget.path));
    //Get first page from document
    PdfPage page = documents.pages[0];
    //Get page size
    Size pageSize = page.getClientSize();
    //Set a standard font
    PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 40);
    //Measure the text
    Size size = font.measureString('Invoice Paid!');
    //Create PDF graphics for the page
    PdfGraphics graphics = page.graphics;
    //Calculate the center point.
    double x = pageSize.width / 2;
    double y = pageSize.height / 2;
    //Save the graphics state for the watermark text
    graphics.save();
    //Tranlate the transform with the center point.
    graphics.translateTransform(x, y);
    //Set transparency level for the text
    graphics.setTransparency(0.25);
    //Rotate the text to -40 Degree
    graphics.rotateTransform(-40);
    //Draw the watermark text to the desired position over the PDF page with red color
    graphics.drawString('Invoice Paid!', font,
        pen: PdfPen(PdfColor(255, 0, 0)),
        brush: PdfBrushes.red,
        bounds: Rect.fromLTWH(
            -size.width / 2, -size.height / 2, size.width, size.height));
    //Restore the graphics
    graphics.restore();
    //Save the document
    List<int> bytes = documents.save();
    //Dispose the document

    // replace the existing pdf and refresh
    setState(() {
      replacePDFWithWatermarked(bytes, widget.label);
      updatePaymentStatusInDb();
    });
    documents.dispose();
  }

  void markPaid() {
    _addWatermarkToPDF();
  }

  static final MethodChannel _platformCall = MethodChannel('launchFile');

  Future<String> replacePDFWithWatermarked(List<int> bytes, String fileName) async {
    String? path;
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isLinux ||
        Platform.isWindows) {
      final Directory directory = await getApplicationDocumentsDirectory();
      path = directory.path;
    } else {
      path = await PathProviderPlatform.instance.getApplicationDocumentsPath();
    }

    final File file =
    File(Platform.isWindows ? '$path\\$fileName' : '$path/$fileName');
    File(Platform.isWindows ? '$path\\$fileName' : '$path/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (Platform.isAndroid || Platform.isIOS) {
      final Map<String, String> argument = <String, String>{
        'file_path': '$path/$fileName'
      };
      try {
        //ignore:

        //   final Future<Map<String, String>?> result =
        _platformCall.invokeMethod('viewPdf', argument);
      } catch (e) {
        throw Exception(e);
      }
    } else if (Platform.isWindows) {
      await Process.run('start', <String>['$path\\$fileName'],
          runInShell: true);
    } else if (Platform.isMacOS) {
      await Process.run('open', <String>['$path/$fileName'], runInShell: true);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', <String>['$path/$fileName'],
          runInShell: true);
    }

    return file.path;
  }

  void updatePaymentStatusInDb() {
    widget._currentInvoice.paid = true;
    widget.invoiceBox..put(widget._currentInvoice);
  }
}