import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'PDFScreen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raysh.io LLC Invoice Generator',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'RAYSH.IO LLC INVOICER'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;


  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _targetFileName = 'Invoice_' + new DateTime.now().millisecond.toString();
  late String _generatedPdfFilePath;

  String _weekOneEndingDate = DateTime.now().toString();
  String _weekTwoEndingDate = DateTime.now().toString();

  double _weekOneHours = 0;
  double _weekTwoHours = 0;

  int _hourlyRate = 105;

  double _weekOneTotal = 0.0;
  double _weekTwoTotal = 0.0;

  String _invoiceNumber = '';

  String _dueDate = '2021/12/10';

  @override
  Widget build(BuildContext context) {
    //initPdfFile();

    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: SizedBox(
            height: 200,
        child: Container(
            child: Column(
          children: [
            SizedBox(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Row(
                    children: [
                      Spacer(flex: 2),
                      Text("$_weekOneEndingDate".split(' ')[0], style: TextStyle(fontSize: 20)),
                      Spacer(flex: 1),
                      ElevatedButton(
                        onPressed: () => _selectWeekOneDate(context),
                        child: Icon(Icons.date_range),
                      ),
                      Spacer(flex: 2,),
                      SizedBox(
                          width: 75,
                          height: 35,
                          child: TextField(
                           onChanged: (val) => {
                      if(val != '')
                      _weekOneHours = int.parse(val).toDouble()
                      },
                            decoration: const InputDecoration(
                                 border: OutlineInputBorder(), hintText: 'Hours'),
                          )),
                      Spacer(flex: 2),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Row(
                    children: [
                      Spacer(flex: 2),
                      Text("$_weekTwoEndingDate".split(' ')[0], style: TextStyle(fontSize: 20)),
                      Spacer(flex: 1),
                      ElevatedButton(
                        onPressed: () => _selectWeekTwoDate(context),
                        child: Icon(Icons.date_range),
                      ),
                      Spacer(flex: 2,),
                      SizedBox(
                          width: 75,
                          height: 35,
                          child: TextField(
                            onChanged: (val) => {
                              if(val != '')
                              _weekTwoHours = int.parse(val).toDouble()
                            },
                            decoration: const InputDecoration(
                                border: OutlineInputBorder(), hintText: 'Hours'),
                          )),
                      Spacer(flex: 2),
                    ],
                  ),
                ],
              ),
            ),
          ],
        )),
      )),
      floatingActionButton: FloatingActionButton(
        onPressed: generateInvoice,
        tooltip: 'Generate Invoice',
        child: Icon(Icons.save, size: 30,),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> _selectWeekOneDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != DateTime.parse(_weekOneEndingDate))
      setState(() {
        _weekOneEndingDate = picked.toString();
      });
  }

  Future<void> _selectWeekTwoDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != DateTime.parse(_weekOneEndingDate))
      setState(() {
        _weekTwoEndingDate = picked.toString();
      });
  }

  Future<void> generateInvoice() async {

    if(!dataIsGood()) return;

    //Create a PDF document.
    final PdfDocument document = PdfDocument();
    //Add page to the PDF
    final PdfPage page = document.pages.add();
    //Get page client size
    final Size pageSize = page.getClientSize();
    //Draw rectangle
    page.graphics.drawRectangle(
        bounds: Rect.fromLTWH(0, 0, pageSize.width, pageSize.height),
        pen: PdfPen(PdfColor(142, 170, 219, 255)));
    //Generate PDF grid.
    final PdfGrid grid = getGrid();
    //Draw the header section by creating text element
    final PdfLayoutResult result = drawHeader(page, pageSize, grid);
    //Draw grid
    drawGrid(page, grid, result);
    //Add invoice footer
    drawFooter(page, pageSize);
    //Save the PDF document
    final List<int> bytes = document.save();
    //Dispose the document.
    document.dispose();
    //Save and launch the file.

    _invoiceNumber = DateTime.now().year.toString() + DateTime.now().month.toString() + DateTime.now().day.toString();

    final String invoiceString = 'Invoice_' + _invoiceNumber + '.pdf';
    final path = await saveAndLaunchFile(bytes, invoiceString);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PDFScreen(path: path)),
    );
  }

  //Draws the invoice header
  PdfLayoutResult drawHeader(PdfPage page, Size pageSize, PdfGrid grid) {
    //Draw rectangle
    page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(91, 126, 215, 255)),
        bounds: Rect.fromLTWH(0, 0, pageSize.width - 115, 90));

    //Draw string
    page.graphics.drawString(
        'RAYSH.IO LLC' + '\r\n' + '1908 Reston Metro Plaza, #1024,'
        + '\r\n' + 'Reston, Va. 20190' + '\r\n\r\n' + 'INVOICE', PdfStandardFont(PdfFontFamily.helvetica, 18),
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(25, 0, pageSize.width - 115, 90),
        format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle));

    page.graphics.drawRectangle(
        bounds: Rect.fromLTWH(400, 0, pageSize.width - 400, 90),
        brush: PdfSolidBrush(PdfColor(65, 104, 205)));

    page.graphics.drawString('INVOICE',
        PdfStandardFont(PdfFontFamily.helvetica, 20),
        bounds: Rect.fromLTWH(400, 0, pageSize.width - 400, 100),
        brush: PdfBrushes.white,
        format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle));

    final PdfFont contentFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
    // //Draw string
    // page.graphics.drawString('Amount', contentFont,
    //     brush: PdfBrushes.white,
    //     bounds: Rect.fromLTWH(400, 0, pageSize.width - 400, 33),
    //     format: PdfStringFormat(
    //         alignment: PdfTextAlignment.center,
    //         lineAlignment: PdfVerticalAlignment.bottom));
    //Create data foramt and convert it to text.
    final DateFormat format = DateFormat.yMMMMd('en_US');

    final String invoiceNumber =      'Invoice Number: ' +  _invoiceNumber
                                + '\r\nInvoice Date: ' + format.format(DateTime.now())
                                + '\r\nDue Date: ' + _dueDate
                                + '\r\nPayment Terms: ' + '\$' +  _hourlyRate.toString() + ' /hr'
        + '\r\nClient Name/location: ' + 'FRB Washington DC'
        + '\r\nConsultant Name: ' + 'Horatio A Cummings';

    final Size contentSize = contentFont.measureString(invoiceNumber);
    // ignore: leading_newlines_in_multiline_strings
    const String address =
               'To: Payroll@viva-it.com'
        + '\r\nViva USA Inc, '
        + '\r\n3601 Algonquin Road, Ste 425'
        + '\r\nRolling Meadows, IL. 60008';

    PdfTextElement(text: invoiceNumber, font: contentFont).draw(
        page: page,
        bounds: Rect.fromLTWH(pageSize.width - (contentSize.width + 30), 120,
            contentSize.width + 30, pageSize.height - 120));

    return PdfTextElement(text: address, font: contentFont).draw(
        page: page,
        bounds: Rect.fromLTWH(30, 120,
            pageSize.width - (contentSize.width + 30), pageSize.height - 120))!;
  }

  //Draws the grid
  void drawGrid(PdfPage page, PdfGrid grid, PdfLayoutResult result) {
    Rect? totalPriceCellBounds;
    Rect? quantityCellBounds;
    //Invoke the beginCellLayout event.
    grid.beginCellLayout = (Object sender, PdfGridBeginCellLayoutArgs args) {
      final PdfGrid grid = sender as PdfGrid;
      if (args.cellIndex == grid.columns.count - 1) {
        totalPriceCellBounds = args.bounds;
      } else if (args.cellIndex == grid.columns.count - 2) {
        quantityCellBounds = args.bounds;
      }
    };
    //Draw the PDF grid and get the result.
    result = grid.draw(
        page: page, bounds: Rect.fromLTWH(0, result.bounds.bottom + 40, 0, 0))!;

    //Draw grand total.
    page.graphics.drawString('Grand Total',
        PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(
            quantityCellBounds!.left,
            result.bounds.bottom + 10,
            quantityCellBounds!.width,
            quantityCellBounds!.height));
    page.graphics.drawString(getTotalAmount(grid).toString(),
        PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(
            totalPriceCellBounds!.left,
            result.bounds.bottom + 10,
            totalPriceCellBounds!.width,
            totalPriceCellBounds!.height));
  }

  //Draw the invoice footer data.
  void drawFooter(PdfPage page, Size pageSize) {
    final PdfPen linePen =
    PdfPen(PdfColor(142, 170, 219, 255), dashStyle: PdfDashStyle.custom);
    linePen.dashPattern = <double>[3, 3];
    //Draw line
    page.graphics.drawLine(linePen, Offset(0, pageSize.height - 100),
        Offset(pageSize.width, pageSize.height - 100));

    const String footerContent =
    // ignore: leading_newlines_in_multiline_strings
    'THANKS FOR YOUR BUSINESS!' + '\r\n\r\n' + 'Any questions?' + '\r\r\n peez@raysh.io';

    //Added 30 as a margin for the layout
    page.graphics.drawString(
        footerContent, PdfStandardFont(PdfFontFamily.helvetica, 9),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
        bounds: Rect.fromLTWH(pageSize.width - 30, pageSize.height - 70, 0, 0));
  }

  //Create PDF grid and return
  PdfGrid getGrid() {
    //Create a PDF grid
    final PdfGrid grid = PdfGrid();
    //Secify the columns count to the grid.
    grid.columns.add(count: 5);
    //Create the header row of the grid.
    final PdfGridRow headerRow = grid.headers.add(1)[0];
    //Set style
    headerRow.style.backgroundBrush = PdfSolidBrush(PdfColor(68, 114, 196));
    headerRow.style.textBrush = PdfBrushes.white;
    headerRow.cells[0].value = 'Week Ending';
    headerRow.cells[0].stringFormat.alignment = PdfTextAlignment.center;
    headerRow.cells[1].value = 'Description Of Work';
    headerRow.cells[2].value = 'Hours Worked';
    headerRow.cells[3].value = 'Rate';
    headerRow.cells[4].value = 'Total';
    //Add rows
    addLineItem(_weekOneEndingDate, 'Application Development', _weekOneHours, _hourlyRate, (_weekOneHours * _hourlyRate), grid);
    addLineItem(_weekTwoEndingDate, 'Application Development', _weekTwoHours, _hourlyRate, (_weekTwoHours * _hourlyRate), grid);

    //Apply the table built-in style
    grid.applyBuiltInStyle(PdfGridBuiltInStyle.listTable4Accent5);
    //Set gird columns width
    grid.columns[1].width = 200;
    for (int i = 0; i < headerRow.cells.count; i++) {
      headerRow.cells[i].style.cellPadding =
          PdfPaddings(bottom: 5, left: 5, right: 5, top: 5);
    }
    for (int i = 0; i < grid.rows.count; i++) {
      final PdfGridRow row = grid.rows[i];
      for (int j = 0; j < row.cells.count; j++) {
        final PdfGridCell cell = row.cells[j];
        if (j == 0) {
          cell.stringFormat.alignment = PdfTextAlignment.center;
        }
        cell.style.cellPadding =
            PdfPaddings(bottom: 5, left: 5, right: 5, top: 5);
      }
    }
    return grid;
  }

  static final MethodChannel _platformCall = MethodChannel('launchFile');

  //Create and row for the grid.
  void addLineItem(String productId, String productName, double price,
      int quantity, double total, PdfGrid grid) {
    final PdfGridRow row = grid.rows.add();
    row.cells[0].value = productId;
    row.cells[1].value = productName;
    row.cells[2].value = price.toString();
    row.cells[3].value = quantity.toString();
    row.cells[4].value = total.toString();
  }

  //Get the total amount.
  double getTotalAmount(PdfGrid grid) {
    double total = 0;
    for (int i = 0; i < grid.rows.count; i++) {
      final String value =
      grid.rows[i].cells[grid.columns.count - 1].value as String;
      total += double.parse(value);
    }
    return total;
  }

   Future<String> saveAndLaunchFile(
      List<int> bytes, String fileName) async {
    String? path;
    if (Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isLinux ||
        Platform.isWindows) {
      final Directory directory = await getApplicationSupportDirectory();
      path = directory.path;
    } else {
      path = await PathProviderPlatform.instance.getApplicationSupportPath();
    }
    final File file =
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

  bool dataIsGood() {
    if(_weekTwoHours == null) return false;
    if(_weekOneHours == null) return false;
    if(_weekOneEndingDate == null) return false;
    if(_weekTwoEndingDate == null || DateTime.parse(_weekTwoEndingDate) == null) return false;
  }
}
