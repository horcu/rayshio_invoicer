import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rayshio_invoicer/models/Invoice.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'PDFScreen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:collection/collection.dart';
import 'helpers/ObjectBox.dart';


/// Provides access to the ObjectBox.dart Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async  {

// This is required so ObjectBox.dart can get the application directory
  // to store the database in.
  WidgetsFlutterBinding.ensureInitialized();

  objectbox = await ObjectBox.create();
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
      home: MyHomePage(title: 'Raysh.io LLC'),
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
  String _errorText = '';
  final DateFormat formatter = DateFormat("yyyy-MM-dd");
  final DateFormat formatter2 = DateFormat.yMMMMd();
  TabController? _tabController;
  int? _activeTabIndex = 0;
  final _invoiceBox = objectbox.store.box<Invoice>();
  String _weekOneEndingDate = '';
  String _weekTwoEndingDate = '';
  double _weekOneHours = 0.0;
  double _weekTwoHours = 0.0;
  int _hourlyRate = 105;
  String _invoiceNumber = '';
  String _defaultClient = 'FRB Washington DC';
  String _consultant = 'Horatio A Cummings';
  late SnackBar snackBar;
  String _dueDate = '';
  String _mainDirectory = '';
  List _fileList = [];
  List<Invoice> _userFriendlyInvoiceList = [];


  _MyHomePageState() {
    _weekOneEndingDate = _format(DateTime.now().subtract(const
    Duration(days: 14)));

    _weekTwoEndingDate = _format(DateTime.now().subtract(const
    Duration(days: 7)));

    _updateInvoiceList();
  }

  @override
  void initState() {
    _dueDate = formatter.format(DateTime.now().add(const Duration(days: 12)));

    super.initState();
  }

  void _setActiveTabIndex() {
    setState(() {
      _activeTabIndex = _tabController?.index;
        _updateInvoiceList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: DefaultTabController(
            length: 2,
            child: Builder(builder: (BuildContext context) {
              _tabController = DefaultTabController.of(context);
              _tabController?.addListener(_setActiveTabIndex);

              return Scaffold(
                  appBar: AppBar(
                    bottom: const TabBar(
                      tabs: [
                        Tab(icon: Icon(Icons.receipt)),
                        Tab(icon: Icon(Icons.list)),
                      ],
                    ),
                    title: Text(widget.title),
                  ),
                  body: TabBarView(
                    children: [
                      Center(
                          child: SizedBox(
                        child: Container(
                            child: Column(
                          children: [
                            Spacer(
                              flex: 1,
                            ),
                            SizedBox(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  Container(
                                      color: Colors.grey,
                                      child: Row(
                                        children: [
                                          Spacer(flex: 2),
                                          Text('Due date',
                                              style: TextStyle(fontSize: 18)),
                                          Spacer(
                                            flex: 7,
                                          ),
                                          Text("$_dueDate".split(' ')[0],
                                              style: TextStyle(fontSize: 16)),
                                          Spacer(flex: 1),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _selectDueDate(context),
                                            child: Icon(Icons.date_range),
                                          ),
                                          Spacer(flex: 2),
                                        ],
                                      )),
                                ],
                              ),
                            ),
                            Spacer(
                              flex: 1,
                            ),
                            SizedBox(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  Row(
                                    children: [
                                      Spacer(flex: 2),
                                      Text('Client:',
                                          style: TextStyle(fontSize: 20)),
                                      Spacer(
                                        flex: 10,
                                      ),
                                      SizedBox(
                                          width: 200,
                                          height: 40,
                                          child: TextField(
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              keyboardType: TextInputType.text,
                                            onChanged: (val) =>
                                                {_defaultClient = val},
                                            decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                                hintText: _defaultClient),
                                          )),
                                      // Text(_defaultClient, style: TextStyle(fontSize: 18)),
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
                                      Text('Consultant:',
                                          style: TextStyle(fontSize: 20)),
                                      Spacer(
                                        flex: 6,
                                      ),
                                      SizedBox(
                                          width: 200,
                                          height: 40,
                                          child: TextField(
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            keyboardType: TextInputType.text,
                                            onChanged: (val) =>
                                                {_consultant = val},
                                            decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                                hintText: _consultant),
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
                                      Spacer(flex: 6),
                                      Text('Payment terms:',
                                          style: TextStyle(fontSize: 20)),
                                      Spacer(
                                        flex: 38,
                                      ),
                                      SizedBox(
                                          width: 80,
                                          height: 40,
                                          child: TextField(
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) =>
                                                {_hourlyRate = int.parse(val)},
                                            decoration: InputDecoration(
                                                border: OutlineInputBorder(),
                                                hintText:
                                                    _hourlyRate.toString()),
                                          )),
                                      Spacer(flex: 6),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Spacer(
                              flex: 1,
                            ),
                            SizedBox(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  Row(
                                    children: [
                                      Spacer(flex: 2),
                                      Text('Week 1:',
                                          style: TextStyle(fontSize: 20)),
                                      Spacer(flex: 5),
                                      Text("$_weekOneEndingDate".split(' ')[0],
                                          style: TextStyle(fontSize: 16)),
                                      Spacer(flex: 1),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _selectWeekOneDate(context),
                                        child: Icon(Icons.date_range),
                                      ),
                                      Spacer(
                                        flex: 1,
                                      ),
                                      SizedBox(
                                          width: 75,
                                          height: 35,
                                          child: TextField(
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) => {
                                              setState((){
                                                  _weekOneHours =
                                                  val == ''
                                                      ? 0.0
                                                      : int.parse(val)
                                                      .toDouble();
                                              })
                                            },
                                            decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                hintText: 'Hours'),
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
                                      Text('Week 2:',
                                          style: TextStyle(fontSize: 20)),
                                      Spacer(flex: 5),
                                      Text("$_weekTwoEndingDate".split(' ')[0],
                                          style: TextStyle(fontSize: 16)),
                                      Spacer(flex: 1),
                                      ElevatedButton(
                                        onPressed: () =>
                                            _selectWeekTwoDate(context),
                                        child: Icon(Icons.date_range),
                                      ),
                                      Spacer(
                                        flex: 1,
                                      ),
                                      SizedBox(
                                          width: 75,
                                          height: 35,
                                          child: TextField(
                                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                            keyboardType: TextInputType.number,
                                            onChanged: (val) => {
                                              setState((){
                                                _weekTwoHours =
                                                val == ''
                                                    ? 0.0
                                                    : int.parse(val).toDouble();
                                                })
                                            },
                                            decoration: const InputDecoration(
                                                border: OutlineInputBorder(),
                                                hintText: 'Hours'),
                                          )),
                                      Spacer(flex: 2),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Spacer(
                              flex: 20,
                            ),
                          ],
                        )),
                      )),
                      Container(
                        child: Column(
                          children: <Widget>[
                            // your Content if there
                            Expanded(
                                child: GridView.builder(
                              itemCount:_userFriendlyInvoiceList.length,
                              itemBuilder: (context, index) => GestureDetector(
                                  onTap: () => {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => PDFScreen(
                                                  key: widget.key,
                                                  path:
                                                      _userFriendlyInvoiceList[
                                                              index]
                                                          .path, label: _userFriendlyInvoiceList[
                                              index]
                                                  .label, invoiceBox:
                                              _invoiceBox, invoiceId:
                                              _userFriendlyInvoiceList[
                                              index].id,)),
                                        )
                                      },
                                  child: Card(
                                    borderOnForeground: true,
                                      margin: EdgeInsets.all(8),
                                      color: Colors.grey[200],
                                      shape: RoundedRectangleBorder(
                                        side: BorderSide(color:
                                        _userFriendlyInvoiceList[index].paid
                                            ? Colors.green
                                            :  Colors.red,
                                            width: 1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Column(children: [
                                            Spacer(flex: 1),
                                            Text(_userFriendlyInvoiceList[index].creationDate),
                                            Spacer(flex: 1),
                                            Icon(
                                              Icons.picture_as_pdf_outlined,
                                              size: 100,
                                            ),
                                            Spacer(flex: 2),
                                            Text(_userFriendlyInvoiceList[index]
                                                .label
                                                .toString()),
                                            Spacer(flex: 10),
                                          ])))),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                              ),
                            ))
                          ],
                        ),
                      )
                    ],
                  ),
              floatingActionButton: new Visibility(
                  visible: _activeTabIndex2,
                  child: FloatingActionButton(
                    onPressed: dataIsGood,
                    tooltip: 'Generate Invoice',
                    child: Icon(
                      Icons.save,
                      size: 30,
                    ),
                  )),
              );
            }),
            initialIndex: 0));
  }

  get _activeTabIndex2 {
    return _activeTabIndex != 1;
  }

  Future<void> _updateInvoiceList() async {
    try {

        _invoiceBox.getAll().forEach((f) {
          var found = _userFriendlyInvoiceList.firstWhereOrNull((element) =>
          element.id == f.id);
          if (found == null) {
            _userFriendlyInvoiceList.add(f);
          } else {
            // replace the record
            _userFriendlyInvoiceList.remove(found);
            _userFriendlyInvoiceList.add(f);
          }
        });

    } catch (ex) {}
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != DateTime.parse(_dueDate))
      setState(() {
        _dueDate = formatter.format(picked);
      });
  }

  Future<void> _selectWeekOneDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2015, 8),
        lastDate: DateTime(2101));
    if (picked != null && picked != DateTime.parse(_weekOneEndingDate))
      setState(() {
        _weekOneEndingDate = formatter.format(picked);
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
        _weekTwoEndingDate = formatter.format(picked);
      });
  }

  Future<void> generateInvoice() async {

    // run validation
    if (!dataIsGood()) return;

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

    _invoiceNumber = _dueDate.toString();

    final String invoiceString = 'Invoice_' + _invoiceNumber + '.pdf';
    final path = await savePdfFile(bytes, invoiceString);

    var label = path.toString().substring(path.length - 22, path.length);
    var invoiceRecord = Invoice(path: path, label: label, dueDate: _dueDate,
        creationDate: formatter.format(DateTime.now()));

    // add invoice to db
     int id = _invoiceBox.put(invoiceRecord);

    // recreate the invoice list
    _updateInvoiceList();

    // close the pop up
    Navigator.of(context).pop();

    // navigate to the completed PDF
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PDFScreen(key: widget.key, path: path, label:
          label, invoiceBox: _invoiceBox, invoiceId: id)),
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
        'RAYSH.IO LLC' +
            '\r\n' +
            '1908 Reston Metro Plaza, #1024,' +
            '\r\n' +
            'Reston, Va. 20190' +
            '\r\n\r\n' +
            'INVOICE',
        PdfStandardFont(PdfFontFamily.helvetica, 18),
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(25, 0, pageSize.width - 115, 90),
        format: PdfStringFormat(lineAlignment: PdfVerticalAlignment.middle));

    page.graphics.drawRectangle(
        bounds: Rect.fromLTWH(400, 0, pageSize.width - 400, 90),
        brush: PdfSolidBrush(PdfColor(65, 104, 205)));

    page.graphics.drawString(
        'INVOICE', PdfStandardFont(PdfFontFamily.helvetica, 20),
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

    final String invoiceNumber = 'Invoice Number: ' +
        _invoiceNumber +
        '\r\nInvoice Date: ' +
        format.format(DateTime.now()) +
        '\r\nDue Date: ' +
        _dueDate +
        '\r\nPayment Terms: ' +
        '\$' +
        _hourlyRate.toString() +
        ' /hr' +
        '\r\nClient Name/location: ' +
        _defaultClient +
        '\r\nConsultant Name: ' +
        _consultant;

    final Size contentSize = contentFont.measureString(invoiceNumber);
    // ignore: leading_newlines_in_multiline_strings
    const String address = 'To: Payroll@viva-it.com' +
        '\r\nViva USA Inc, ' +
        '\r\n3601 Algonquin Road, Ste 425' +
        '\r\nRolling Meadows, IL. 60008';

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
        'THANKS FOR YOUR BUSINESS!' +
            '\r\n\r\n' +
            'Any questions?' +
            '\r\r\n peez@raysh.io';

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
    addLineItem(_weekOneEndingDate, 'Application Development', _weekOneHours,
        _hourlyRate, (_weekOneHours * _hourlyRate), grid);
    addLineItem(_weekTwoEndingDate, 'Application Development', _weekTwoHours,
        _hourlyRate, (_weekTwoHours * _hourlyRate), grid);

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
  void addLineItem(String weekEnding, String workType, double HoursWorked, int rate, double total, PdfGrid grid) {
    final PdfGridRow row = grid.rows.add();
    row.cells[0].value = weekEnding;
    row.cells[1].value = workType;
    row.cells[2].value = HoursWorked.toString();
    row.cells[3].value = rate.toString();
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

  Future<String> savePdfFile(List<int> bytes, String fileName) async {
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

  Future<void> _showMyDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create Invoice?', style: TextStyle
            (fontSize: 24) ),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Row(children: [Text('Week one: ' + _weekOneHours.toString() +
                    ' hrs ' + ': \$' + (_weekOneHours* _hourlyRate).toString
                  ())]),
                Row(children: [Text('Week two: ' + _weekTwoHours.toString() +
                    ' hrs'+ ': \$' + (_weekTwoHours* _hourlyRate).toString
                  ()),],),
                Row(children: [Text('Total' +  ': \$' + ((_weekOneHours*
                    _hourlyRate) +
                    (_weekTwoHours* _hourlyRate)).toString(),
                )]),
                Row(children: [Text('Due: ' + formatter2.format(DateTime
                    .parse(_dueDate)),
                )]),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Confirm'),
              onPressed: () {
                print('Confirmed');
                Navigator.of(context).pop();
                generateInvoice();
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

  bool dataIsGood() {
    if (_weekOneHours == 0.0) {
      // final snackBar =
      //     SnackBar(content: Text('Hours for week 1 isn\'t selected'));
      // ScaffoldMessenger.of(context).showSnackBar(snackBar);
      Fluttertoast.showToast(
          msg: "Hours for week 1 isn\'t selected",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey,
          textColor: Colors.grey,
          fontSize: 16.0
      );
      return false;
    }

    if (_weekTwoHours == 0.0) {
      Fluttertoast.showToast(
          msg: "Hours for week 2 isn\'t selected",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey,
          textColor: Colors.grey,
          fontSize: 16.0
      );
      return false;
    }

    DateTime parsedWeekOneDate = DateTime.parse(_weekOneEndingDate);
    final parsedWeekTwoDate = DateTime.parse(_weekTwoEndingDate);

    if (parsedWeekOneDate == DateTime.now() ||
        // parsedWeekOneDate.isAfter(DateTime.now()) ||
        parsedWeekTwoDate == DateTime.now() ||
        //  parsedWeekTwoDate.isAfter(DateTime.now()) ||
        parsedWeekOneDate.isAfter(parsedWeekTwoDate)) {
      Fluttertoast.showToast(
          msg: "Week 2\'s date must come after week 1\'s date",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey,
          textColor: Colors.grey,
          fontSize: 16.0
      );
      return false;
    }
    var days = parsedWeekTwoDate.difference(parsedWeekOneDate).inDays;
    if (days < 7) {
      Fluttertoast.showToast(
          msg: "Weeks one and two must be exactly a week apart",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.grey,
          textColor: Colors.grey,
          fontSize: 16.0
      );
      return false;
    }

    // all is good so show the confirmation dialog
    _showMyDialog();
    return true;
  }

   String _format(DateTime d) {
    return formatter.format(d.toUtc());
  }
}
