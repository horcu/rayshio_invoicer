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
import 'package:fluttertoast/fluttertoast.dart';
import 'package:collection/collection.dart';
import 'helpers/ObjectBox.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'helpers/notifications.dart';
import 'helpers/utilities.dart';
import 'models/Association.dart';
import 'models/Client.dart';
import 'models/Consultant.dart';
import 'models/DdItem.dart';
import 'models/PayRate.dart';
import 'objectbox.g.dart';

/// Provides access to the ObjectBox.dart Store throughout the app.
late ObjectBox objectbox;

Future<void> main() async {
  AwesomeNotifications().initialize(
    'resource://drawable/ic_launcher',
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic Notifications',
        defaultColor: Colors.blueGrey,
        importance: NotificationImportance.High,
        channelShowBadge: true, channelDescription: '',
      ),
      NotificationChannel(
        channelKey: 'scheduled_channel',
        channelName: 'Scheduled Notifications',
        defaultColor: Colors.blueGrey,
        locked: true,
        //icon: "resource://drawable/ic_launcher.png",
        importance: NotificationImportance.High, channelDescription: '',
        // soundSource: 'resource://raw/res_custom_notification',
      ),
    ],
  );

// This is required so ObjectBox.dart can get the application directory
  // to store the database in.
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
  final DateFormat formatter3 = DateFormat("yyyyMMdd");
  TabController? _tabController;
  int? _activeTabIndex = 0;
  final _invoiceBox = objectbox.store.box<Invoice>();
  final _ratesBox = objectbox.store.box<PayRate>();
  final _clientsBox = objectbox.store.box<Client>();
  final _consultantsBox = objectbox.store.box<Consultant>();
  final _associationBox = objectbox.store.box<Association>();
  String _weekOneEndingDate = '';
  String _weekTwoEndingDate = '';
  double _weekOneHours = 0.0;
  double _weekTwoHours = 0.0;
  int _hourlyRate = 105;
  late String _invoiceNumber;
  late DdItem _selectedHourlyRate = DdItem(id: 0, name: 'Select Rate');
  late DdItem _selectedClient = DdItem(id: 0, name: 'Select Client');
  late DdItem _selectedConsultant = DdItem(id: 0, name: 'Select Consultant');
  late DdItem _selectedAssociation = DdItem(id: 0,name: 'No association chosen');

  late List<DdItem> _clients;
  late List<DdItem> _associations;
  late List<DdItem> _consultants;
  late List<DdItem> _hourlyRates;

  late SnackBar snackBar;
  String _dueDate = '';

  List<Invoice> _userFriendlyInvoiceList = [];

  late List<Client> partners = [];

  var sub1;
  var sub2;
  var sub3;
  var sub4;
  var sub5;

  String isSelected = "reminders";
  late Admin admin;
  late Client _selectedClientWithDetails = new Client() ;

  late List<Association> _boxAssociationsList;

  _MyHomePageState() {

     deleteAllFromAllDbs();
    if (Admin.isAvailable()) {
      // Keep a reference until no longer needed or manually closed.
      admin = Admin(objectbox.store);
    }
    _weekOneEndingDate =
        _format(DateTime.now().subtract(const Duration(days: 14)));

    _weekTwoEndingDate =
        _format(DateTime.now().subtract(const Duration(days: 7)));

    _updateInvoiceList();
    _activeTabIndex = 0;

    _associations = <DdItem>[];
    _boxAssociationsList = _getAssociations();
    _boxAssociationsList.forEach((a){
      _associations.add(generateAssociationItem(a));
    });
    _associations.add(DdItem(id: 0, name: "No association chosen"));
    _selectedAssociation = _associations[0];

    _consultants = <DdItem>[];
    var cs = _getConsultants();
    cs.forEach((c) {
      _consultants.add(DdItem(id: c.id, name: c.name));
    });
    _consultants.add(DdItem(id: 0, name: 'Select Consultant'));
    _selectedConsultant = _consultants[0];

    _clients = <DdItem>[];
    var cl = _getClients();
    cl.forEach((c) {
      _clients.add(DdItem(id: c.id, name: c.name));
    });

    _clients.add(DdItem(id: -1, name: 'Select Client'));
    _selectedClient = _clients[0];


    _hourlyRates = <DdItem>[];
    var rt = _getHourlyRates();
    rt.forEach((c) {
      _hourlyRates.add(DdItem(id: c.id, name: c.rate));
    });

    _hourlyRates.add(DdItem(id: 0, name: 'Select Rate'));

    _selectedHourlyRate = _hourlyRates[0];
    
    if(_associations.length > 1 && _boxAssociationsList.length > 1) {
       // if association chosen then go with its client Id to find  the 
      // details of the client

      _selectedClientWithDetails = _clientsBox.get(_boxAssociationsList[1]
          .clientId)!;
    } 

    watchClients();
    watchPayRates();
    watchConsultants();
    watchAssociations();
    watchInvoices();
  }

  @override
  void initState() {
    _dueDate = formatter.format(DateTime.now().add(const Duration(days: 12)));
    super.initState();

    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Allow Notifications'),
            content: Text('Our app would like to send you notifications'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'Don\'t Allow',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 18,
                  ),
                ),
              ),
              TextButton(
                  onPressed: () => AwesomeNotifications()
                      .requestPermissionToSendNotifications()
                      .then((_) => Navigator.pop(context)),
                  child: Text(
                    'Allow',
                    style: TextStyle(
                      color: Colors.teal,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ))
            ],
          ),
        );
      }
    });

    AwesomeNotifications().createdStream.listen((notification) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Notification Created on ${notification.channelKey}',
        ),
      ));
    });

    AwesomeNotifications().actionStream.listen((notification) {
      if (notification.channelKey == 'basic_channel' && Platform.isIOS) {
        AwesomeNotifications().getGlobalBadgeCounter().then(
              (value) =>
                  AwesomeNotifications().setGlobalBadgeCounter(value - 1),
            );
      }

      // Navigator.pushAndRemoveUntil(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => PlantStatsPage(),
      //   ),
      //       (route) => route.isFirst,
      // );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: DefaultTabController(
            length: 3,
            child: Builder(builder: (BuildContext context) {
              _tabController = DefaultTabController.of(context);
              _tabController?.addListener(_setActiveTabIndex);

              return Scaffold(
                backgroundColor: const Color(0xFFE3E7F1),
                appBar: AppBar(
                  //  bottom:
                  title: Text(widget.title),
                ),
                bottomNavigationBar: Container(
                    color: Colors.blue,
                    child: const TabBar(
                      labelColor: Colors.white,
                      unselectedLabelColor: const Color(0xFFE3E7F1),
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorPadding: EdgeInsets.all(5.0),
                      indicatorColor: const Color(0xFFE3E7F1),
                      tabs: [
                        Tab(icon: Icon(Icons.receipt)),
                        Tab(icon: Icon(Icons.list)),
                        Tab(icon: Icon(Icons.settings)),
                      ],
                    )),
                body: TabBarView(
                  children: [
                    SizedBox(
                      child: Container(
                          child: Form(
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
                                    child: Row(
                                  children: [
                                    Spacer(flex: 2),
                                    Text('Due date',
                                        style: TextStyle(fontSize: 18)),
                                    Spacer(
                                      flex: 13,
                                    ),
                                    Text("$_dueDate".split(' ')[0],
                                        style: TextStyle(fontSize: 16)),
                                    Spacer(flex: 1),
                                    ElevatedButton(
                                      onPressed: () => _selectDueDate(context),
                                      child: Icon(Icons.date_range),
                                    ),
                                    Spacer(flex: 2),
                                  ],
                                )),
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
                                    SizedBox(
                                        width: 380,
                                        height: 50,
                                        child: DropdownButton<DdItem>(
                                          isExpanded: true,
                                          value: _selectedAssociation,
                                          // hint: Text('--Select
                                          // Association--'),
                                          items: _associations.map((DdItem c) {
                                            return DropdownMenuItem<DdItem>(
                                              child: new Text(c.name),
                                              value: c,
                                            );
                                          }).toList(),
                                          onChanged: (val) => {
                                            setState(() {
                                              _selectedAssociation = val!;
                                            })
                                          },
                                        )),
                                    Spacer(flex: 2),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Visibility(
                            visible: _selectedAssociation.name ==
                                'No association'
                                    ' chosen',
                            child: SizedBox(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: <Widget>[
                                  Row(
                                    children: [
                                      Spacer(flex: 2),
                                      SizedBox(
                                          width: 380,
                                          height: 50,
                                          child: DropdownButton<DdItem>(
                                            isExpanded: true,
                                            value: _selectedClient,
                                            // hint: Text('--Select Client--'),
                                            items: _clients.map((DdItem c) {
                                              return DropdownMenuItem<DdItem>(
                                                child: new Text(c.name),
                                                value: c,
                                              );
                                            }).toList(),
                                            onChanged: (val) => {
                                              setState(() {
                                                _selectedClient = val!;
                                               var res = _clientsBox.get(val
                                                   .id)!;
                                               if(_boxAssociationsList.length
                                               > 0) {
                                                 _selectedClientWithDetails =
                                                 _clientsBox.get(
                                                     _boxAssociationsList[1]
                                                         .clientId)!;
                                               }
                                              })
                                            },
                                          )),
                                      Spacer(flex: 2),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Visibility(
                              visible: _selectedAssociation.name ==
                                  'No '
                                      'association chosen',
                              child: SizedBox(
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Spacer(flex: 2),
                                        // Text('Consultant:',
                                        //     style: TextStyle(fontSize: 20)),
                                        // Spacer(
                                        //   flex: 6,
                                        // ),
                                        SizedBox(
                                            width: 380,
                                            height: 50,
                                            child: DropdownButton<DdItem>(
                                              isExpanded: true,
                                              value: _selectedConsultant,
                                              // hint: Text('--Select Consultant--'),
                                              items:
                                                  _consultants.map((DdItem c) {
                                                return DropdownMenuItem(
                                                  child: new Text(c.name),
                                                  value: c,
                                                );
                                              }).toList(),
                                              onChanged: (val) => {
                                                setState(() {
                                                  _selectedConsultant = val!;
                                                })
                                              },
                                            )),
                                        Spacer(flex: 2),
                                      ],
                                    ),
                                  ],
                                ),
                              )),
                          Visibility(
                              visible: _selectedAssociation.name ==
                                  'No '
                                      'association chosen',
                              child: SizedBox(
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: <Widget>[
                                    Row(
                                      children: [
                                        Spacer(flex: 1),
                                        SizedBox(
                                            width: 380,
                                            height: 50,
                                            child: DropdownButton<DdItem>(
                                              isExpanded: true,
                                              value: _selectedHourlyRate,
                                              // hint: Text('--Select Rate--'),
                                              items:
                                                  _hourlyRates.map((DdItem c) {
                                                return DropdownMenuItem(
                                                  child: new Text(c.name),
                                                  value: c,
                                                );
                                              }).toList(),
                                              onChanged: (val) => {
                                                setState(() {
                                                  _selectedHourlyRate = val!;
                                                })
                                              },
                                            )),
                                        Spacer(flex: 1),
                                      ],
                                    ),
                                  ],
                                ),
                              )),
                          SizedBox(
                            child: Container(
                                child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                Row(
                                  children: [
                                    Spacer(flex: 2),
                                    Text('Week one end date:',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54)),
                                    Spacer(flex: 13),
                                    SizedBox(
                                        width: 100,
                                        child: Text(
                                            "$_weekOneEndingDate".split(' ')[0],
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54))),
                                    Spacer(flex: 1),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _selectWeekOneDate(context),
                                      child: Icon(Icons.date_range),
                                    ),
                                    Spacer(flex: 5),
                                  ],
                                ),
                              ],
                            )),
                          ),
                          SizedBox(
                              width: 380,
                              height: 50,
                              child: TextField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                keyboardType: TextInputType.number,
                                onChanged: (val) => {
                                  setState(() {
                                    _weekOneHours = val == ''
                                        ? 0.0
                                        : int.parse(val).toDouble();
                                  })
                                },
                                decoration: const InputDecoration(
                                    border: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white)),
                                    fillColor: Colors.black38,
                                    hintText: 'Hours'),
                              )),
                          SizedBox(
                            child: Container(
                                child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                Row(
                                  children: [
                                    Spacer(flex: 2),
                                    Text('Week 2 end date:',
                                        style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black54)),
                                    Spacer(flex: 13),
                                    SizedBox(
                                        width: 100,
                                        child: Text(
                                            "$_weekTwoEndingDate".split(' ')[0],
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.black54))),
                                    Spacer(flex: 1),
                                    ElevatedButton(
                                      onPressed: () =>
                                          _selectWeekTwoDate(context),
                                      child: Icon(Icons.date_range),
                                    ),
                                    Spacer(
                                      flex: 5,
                                    ),
                                  ],
                                ),
                              ],
                            )),
                          ),
                          SizedBox(
                              width: 380,
                              height: 50,
                              child: TextField(
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                keyboardType: TextInputType.number,
                                onChanged: (val) => {
                                  setState(() {
                                    _weekTwoHours = val == ''
                                        ? 0.0
                                        : int.parse(val).toDouble();
                                  })
                                },
                                decoration: const InputDecoration(
                                    border: UnderlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white)),
                                    fillColor: Colors.white,
                                    hintText: 'Hours'),
                              )),
                          Spacer(
                            flex: 5,
                          ),
                        ],
                      ))),
                    ),
                    Container(
                      child: Form(
                          child: Column(children: [
                            Spacer(
                              flex: 1,
                            ),
                            ExpansionTile(
                              title: Text('Reminders'),
                              subtitle: Text('Invoice reminders'),
                              children: <Widget>[
                                Row(children: [
                                  Spacer(flex: 1),
                                  Text("Invoice due reminder"),
                                  Spacer(
                                    flex: 10,
                                  ),
                                  ElevatedButton(
                                      onPressed: () {
                                        createNotification();
                                      },
                                      child: Container(
                                        child: Icon(Icons.alarm),
                                      )),
                                  Spacer(flex: 1),
                                ])
                              ],
                            ),
                            ExpansionTile(
                              title: Text('Consultants'),
                              subtitle: Text('Add promote or remove '
                                  'resources'),
                              children: <Widget>[
                                Row(children: [
                                  Spacer(flex: 1),
                                  Text("Add new Consultant"),
                                  Spacer(
                                    flex: 10,
                                  ),
                                  ElevatedButton(
                                      onPressed: () {
                                        _showAddConsultantDialog();
                                      },
                                      child: Container(
                                        child: Icon(
                                            Icons.supervised_user_circle_rounded),
                                      )),
                                  Spacer(flex: 1),
                                ]),
                                SizedBox(
                                    height: 180,
                                    child: ListView.builder(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: _consultants.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          return UnconstrainedBox(
                                              alignment:
                                              AlignmentDirectional.centerStart,
                                              child: ChipItem(
                                                  _consultants[index].name,
                                                  _consultants[index].id,
                                                  'consultant'));
                                        }))
                              ],
                            ),
                            ExpansionTile(
                              title: Text('Clients'),
                              subtitle: Text('manage clients'),
                              children: <Widget>[
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                    Text("Add new Client"),
                                    Spacer(
                                      flex: 10,
                                    ),
                                    ElevatedButton(
                                        onPressed: () {
                                          _showAddClientDialog();
                                        },
                                        child: Container(
                                          child: Icon(Icons.add_business_outlined),
                                        )),
                                    Spacer(flex: 1),
                                  ],
                                ),
                                SizedBox(
                                    height: 180,
                                    child: ListView.builder(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: _clients.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          return UnconstrainedBox(
                                              alignment:
                                              AlignmentDirectional.centerStart,
                                              child: ChipItem(
                                                  _clients[index].name,
                                                  _clients[index].id,
                                                      'client'));
                                        }))
                              ],
                            ),
                            ExpansionTile(
                              title: Text('Payments'),
                              subtitle: Text('Pay rate creation and '
                                  'associations'),
                              children: <Widget>[
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                    Spacer(
                                      flex: 20,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                    Text("Pay rates"),
                                    Spacer(
                                      flex: 12,
                                    ),
                                    ElevatedButton(
                                        onPressed: () {
                                          _showAddPayRateDialog();
                                        },
                                        child: Container(
                                          child: Icon(Icons.add),
                                        )),
                                    Spacer(flex: 1),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                    Spacer(
                                      flex: 18,
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: 100,
                                    child: ListView.builder(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: _hourlyRates.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          return UnconstrainedBox(
                                              alignment:
                                              AlignmentDirectional.centerStart,
                                              child: UnconstrainedBox(
                                                  alignment: AlignmentDirectional
                                                      .centerStart,
                                                  child: UnconstrainedBox(
                                                      alignment:
                                                      AlignmentDirectional
                                                          .centerStart,
                                                      child: ChipItem(
                                                          _hourlyRates[index].name,
                                                          _hourlyRates[index].id,
                                                          'rate'))));
                                        }))
                              ],
                            ),
                            ExpansionTile(
                              title: Text('Associations'),
                              subtitle: Text('client, consultant and pay '
                                  'rate association'),
                              children: <Widget>[
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                    Spacer(
                                      flex: 20,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                    Spacer(
                                      flex: 18,
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Spacer(flex: 1),
                                    Text("associations"),
                                    Spacer(
                                      flex: 11,
                                    ),
                                    ElevatedButton(
                                        onPressed: () {
                                          _showAssociationDialog();
                                        },
                                        child: Container(
                                          child: Icon(Icons.add),
                                        )),
                                    Spacer(flex: 1),
                                  ],
                                ),
                                SizedBox(
                                    height: 180,
                                    child: ListView.builder(
                                        padding: const EdgeInsets.all(8),
                                        itemCount: _associations.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          return UnconstrainedBox(
                                              alignment:
                                              AlignmentDirectional.centerStart,
                                              child: ChipItem(
                                                  _associations[index].name,
                                                  _associations[index].id,
                                                  'association'));
                                        }))
                              ],
                            ),
                            Spacer(flex: 10),
                          ])),
                    ),
                    Container(
                      child: Column(
                        children: <Widget>[
                          // your Content if there
                          Expanded(
                              child: GridView.builder(
                            itemCount: _userFriendlyInvoiceList.length,
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
                                                          .path,
                                                  label:
                                                      _userFriendlyInvoiceList[
                                                              index]
                                                          .label,
                                                  invoiceId:
                                                      _userFriendlyInvoiceList[
                                                              index]
                                                          .id,
                                                  invoiceBox: _invoiceBox,
                                              clientBox: _clientsBox,
                                                )),
                                      )
                                    },
                                child: Card(
                                    borderOnForeground: true,
                                    margin: EdgeInsets.all(8),
                                    color: Colors.grey[200],
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                          color: _userFriendlyInvoiceList[index]
                                                  .paid
                                              ? Colors.green
                                              : Colors.red,
                                          width: 1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Column(children: [
                                          Spacer(flex: 1),
                                          Text(_userFriendlyInvoiceList[index]
                                              .creationDate),
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
                    ),
                  ],
                ),
                floatingActionButton: new Visibility(

                    visible: _activeTabIndex2,
                    child: FloatingActionButton(
                      heroTag: null,
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

  @override
  void dispose() {
    AwesomeNotifications().actionSink.close();
    AwesomeNotifications().createdSink.close();
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    sub4.cancel();
  //  admin.close();
    super.dispose();
  }

  get _activeTabIndex2 {
    return _activeTabIndex != 1 && _activeTabIndex != 2;
  }

  void _setActiveTabIndex() {
    setState(() {
      _activeTabIndex = _tabController?.index;
      _updateInvoiceList();
    });
  }

  Future<void> _updateInvoiceList() async {
    try {
      _invoiceBox.getAll().forEach((f) {
        var found = _userFriendlyInvoiceList
            .firstWhereOrNull((element) => element.id == f.id);
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
        lastDate: DateTime.parse(_dueDate));
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
        lastDate: DateTime.parse(_dueDate));
    if (picked != null && picked != DateTime.parse(_weekOneEndingDate))
      setState(() {
        _weekTwoEndingDate = formatter.format(picked);
      });
  }

  Future<void> generateInvoice() async {
    // run validation
    if (!dataIsGood()) return;

    // ensure that if an association is chosen that the correct selected
    // client consultant and pay rate is chosen.
    if (_selectedAssociation.name != "No association chosen") {
      var association = _associationBox.get(_selectedAssociation.id);
      if (association != null) {
        var client = _clientsBox.get(association.clientId);
        _selectedClient = DdItem(id: client!.id, name: client.name);

        var consultant = _consultantsBox.get(association.consultantId);
        _selectedConsultant = DdItem(id: consultant!.id, name: consultant.name);
        var rate = _ratesBox.get(association.rateId);
        _selectedHourlyRate = DdItem(id: rate!.id, name: rate.rate);
      }
    }

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

    _invoiceNumber = formatter3.format(DateTime.parse(_dueDate));

    final String invoiceString = 'Invoice_' + _invoiceNumber + '.pdf';
    final path = await savePdfFile(bytes, invoiceString);

    var label = path.toString().substring(path.length - 22, path.length);
    var invoiceRecord = Invoice(
        path: path,
        clientId: _selectedClient.id,
        label: label,
        dueDate: _dueDate,
        creationDate: formatter.format(DateTime.now()));

    // add invoice to db
    int id = _invoiceBox.put(invoiceRecord);

    // recreate the invoice list
    _updateInvoiceList();

    // clear fields
    _weekOneHours = 0.0;
    _weekTwoHours = 0.0;

    // close the pop up
    Navigator.of(context).pop();

    // navigate to the completed PDF
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => PDFScreen(
                key: widget.key,
                path: path,
                label: label,
                invoiceId: id,
                invoiceBox: _invoiceBox,
            clientBox: _clientsBox,
              )),
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
        formatter3.format(DateTime.parse(_dueDate)) +
        '\r\nInvoice Date: ' +
        format.format(DateTime.now()) +
        '\r\nDue Date: ' +
        _dueDate +
        '\r\nPayment Terms: ' +
        '\$' +
        _hourlyRate.toString() +
        ' /hr' +
        '\r\nClient Name/location: ' +
        _selectedClient.name +
        '\r\nConsultant Name: ' +
        _selectedConsultant.name;

    if (_selectedClientWithDetails == null ) {
      throw("Fatal PDF generation error: cannot find client information");
    }

    final Size contentSize = contentFont.measureString(invoiceNumber);
    // ignore: leading_newlines_in_multiline_strings
     String address = _selectedClientWithDetails.name.toString()  + // 'To:  BigRio  LLC'
        '\r\n' + _selectedClientWithDetails.address1  + ', ' +
        '\r\n' + _selectedClientWithDetails.address2 + ', ' +
        '\r\n' + _selectedClientWithDetails.address3 + ', ' +
        '\r\n' + _selectedClientWithDetails.address4 ;


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
  void addLineItem(String weekEnding, String workType, double HoursWorked,
      int rate, double total, PdfGrid grid) {
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

  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('INVOICE', style: TextStyle(fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Row(children: [
                  Text(
                    'Due: ' + formatter2.format(DateTime.parse(_dueDate)),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 40,
                  ),
                ]),
                Row(children: [
                  Text('Week one: ' +
                      _weekOneHours.toString() +
                      ' hrs ' +
                      ' \$' +
                      (_weekOneHours * _hourlyRate).toString())
                ]),
                Row(
                  children: [
                    Text('Week two: ' +
                        _weekTwoHours.toString() +
                        ' hrs ' +
                        ' \$' +
                        (_weekTwoHours * _hourlyRate).toString()),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 220,
                      height: 2,
                      color: Colors.grey,
                    )
                  ],
                ),
                Row(children: [
                  Text('Total'),
                  Spacer(flex: 7),
                  Text('\$' +
                      ((_weekOneHours * _hourlyRate) +
                              (_weekTwoHours * _hourlyRate))
                          .toString()),
                  Spacer(
                    flex: 2,
                  ),
                ]),
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
          fontSize: 16.0);
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
          fontSize: 16.0);
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
          fontSize: 16.0);
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
          fontSize: 16.0);
      return false;
    }

    // all is good so show the confirmation dialog
    _showConfirmationDialog();
    return true;
  }

  String _format(DateTime d) {
    return formatter.format(d.toUtc());
  }

  Future<void> createNotification() async {
    NotificationWeekAndTime? pickedSchedule = await pickSchedule(context);

    if (pickedSchedule != null) {
      createInvoiceNotification(pickedSchedule);
    }
  }

  List<Consultant> _getConsultants() {
    return _consultantsBox.getAll();
  }

  List<Client> _getClients() {
    return _clientsBox.getAll();
  }

  List<PayRate> _getHourlyRates() {
    return _ratesBox.getAll();
  }

  List<Association> _getAssociations(){
    return _associationBox.getAll();
  }

  Future<void> _showAddClientDialog() async {
    var nm = '';
    var add1 = '';
    var add2 = '';
    var add3 = '';
    var add4 = '';

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add a new Client', style: TextStyle(fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      nm = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'name'),
                ),
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      add1 = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'address 1'),
                ),
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      add2 = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'address 2'),
                ),
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      add3 = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'address 3'),
                ),
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      add4 = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'address 4'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                print('Save client ' + nm);
                Navigator.of(context).pop();
                var client = Client();
                client.name= nm;  client.address1= add1;  client.address2= add2;
                client.address3= add3;  client.address4= add4 ;
                addNewClient(client);
              },
            ),
          ],
        );
      },
    );
  }

  void addNewClient(Client c) {
    _clientsBox.put(c);
  }

  Future<void> _showAddPayRateDialog() async {
    var payRate = '0';
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add new Pay Rate', style: TextStyle(fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      payRate = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'Rate/hr'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                print('Save rate ' + payRate);
                Navigator.of(context).pop();
                var rate = PayRate(rate: payRate);
                addPayRate(rate);
              },
            ),
          ],
        );
      },
    );
  }

  void addPayRate(PayRate p) {
    _ratesBox.put(p);
  }

  Future<void> _showAddConsultantDialog() async {
    var consultantName;
    var consultantTitle;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add a new Consultant', style: TextStyle(fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      consultantName = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'Name'),
                ),
                TextField(
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter
                  ],
                  keyboardType: TextInputType.text,
                  onChanged: (val) => {
                    setState(() {
                      consultantTitle = val;
                    })
                  },
                  decoration: const InputDecoration(
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white)),
                      fillColor: Colors.white,
                      hintText: 'title'),
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                print('Save consultant ' + consultantName);
                Navigator.of(context).pop();
                var consultant =
                    Consultant(name: consultantName, title: consultantTitle);
                addConsultant(consultant);
              },
            ),
          ],
        );
      },
    );
  }

  void addConsultant(Consultant c) {
    _consultantsBox.put(c);
  }

  void watchClients() {
    Stream<Query<Client>> watchedClients = _clientsBox.query().watch();
    sub1 = watchedClients.listen((Query<Client> query) {
      // This gets triggered once right away and then after queried entity types changes.

      _getClients().forEach((client) {
        if (_clients.firstWhereOrNull((c) => c.id == client.id) == null) {
          setState(() {
            _clients.add(DdItem(id: client.id, name: client.name));
          });
        }
      });
    });
  }

  void watchPayRates() {
    Stream<Query<PayRate>> watchedClients = _ratesBox.query().watch();
    sub2 = watchedClients.listen((Query<PayRate> query) {
      // This gets triggered once right away and then after queried entity types changes.

      _getHourlyRates().forEach((pr) {
        if (_hourlyRates.firstWhereOrNull((c) => c.id == pr.id) == null) {
          setState(() {
            _hourlyRates.add(DdItem(id: pr.id, name: pr.rate));
          });
        }
      });
    });
  }

  void watchConsultants() {
    Stream<Query<Consultant>> watchedClients = _consultantsBox.query().watch();
    sub3 = watchedClients.listen((Query<Consultant> query) {
      // This gets triggered once right away and then after queried entity types changes.

      _getConsultants().forEach((c) {
        if (_consultants.firstWhereOrNull((element) => element.id == c.id) ==
            null) {
          setState(() {
            _consultants.add(DdItem(id: c.id, name: c.name));
          });
        }
      });
    });
  }

  void watchAssociations() {
    Stream<Query<Association>> watchedAssociations =
        _associationBox.query().watch();
    sub4 = watchedAssociations.listen((Query<Association> query) {
      // This gets triggered once right away and then after queried entity types changes.

      _getAssociations().forEach((a) {
        if (_associations.firstWhereOrNull((element) => element.id == a.id) ==
            null) {
          setState(() {
              _associations.add(generateAssociationItem(a));
          });
        }
      });
    });
  }

  void watchInvoices() {
    Stream<Query<Invoice>> watchedInvoices =
    _invoiceBox.query().watch();
    sub5 = watchedInvoices.listen((Query<Invoice> query) {
      // This gets triggered once right away and then after queried entity types changes.
      _invoiceBox.getAll().forEach((f) {
        var found = _userFriendlyInvoiceList
            .firstWhereOrNull((element) => element.id == f.id);
        if (found == null) {
          _userFriendlyInvoiceList.remove(found);
          _userFriendlyInvoiceList.add(f);
        } else {
          // replace the record

          _userFriendlyInvoiceList.add(f);
        }
      });

    });
  }

  ChipItem(String name, int id, String type) {
    return Chip(
        onDeleted: () =>  {
          deleteEntity(id, type)
        },
        backgroundColor: Colors.grey.shade50,
        avatar: CircleAvatar(
          backgroundColor: Colors.grey.shade800,
          child: Text(name.length > 2 ? name.substring(0, 1) : 'A'),
        ),
        label: SizedBox(
          height: 30,
          child: Row(
              children: [Text(name.length < 40 ? name : name.substring(0, 40))]),
        ));
  }

  Future<void> _showAssociationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Make Association?', style: TextStyle(fontSize: 24)),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                Column(
                  children: [
                    Row(children: [
                      searchBar(getSelectedClientLabel),
                      Spacer(
                        flex: 1,
                      )
                    ]),
                    Row(children: [
                      searchBar(getSelectedConsultantLabel),
                      Spacer(
                        flex: 1,
                      )
                    ]),
                    Row(children: [
                      searchBar(getSelectedPayRateLabel),
                      Spacer(
                        flex: 1,
                      )
                    ]),
                  ],
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Save'),
              onPressed: () {
                print('Confirmed');
                Navigator.of(context).pop();
                makeClientResourceRateAssociation();
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

  searchBar(Function func) {
    return Text(func());
  }

  void makeClientResourceRateAssociation() {
    _associationBox.put(Association(
        clientId: getSelectedClient()!.id,
        consultantId: getSelectedConsultant()!.id,
        rateId: getSelectedPayRate()!.id));
  }

  Client? getSelectedClient() {
    return _clientsBox.get(_selectedClient.id);
  }

  Consultant? getSelectedConsultant() {
    return _consultantsBox.get(_selectedConsultant.id);
  }

  PayRate? getSelectedPayRate() {
    return _ratesBox.get(_selectedHourlyRate.id);
  }

  DdItem generateAssociationItem( Association a) {

      var association = _associationBox.get(a.id);
      var client = _clientsBox.get(a.clientId);
      var consultant = _consultantsBox.get(a.consultantId);
      var rate = _ratesBox.get(a.rateId);
      return DdItem(
          id: association?.id ?? 0,
          name: consultant!.name +
              '-' +
              client!.name +
              '-' +
              '\$' +
              rate!.rate +
              '/hr');
  }

  void deleteEntity(int id, String type) {
    switch (type) {
      case 'client':
        {
          setState(() {
            _clientsBox.remove(id);
          });
          break;
        }
      case 'consultant':
        {
          setState(() {
            _consultantsBox.remove(id);
          });
          break;
        }
      case 'association':
        {
          setState(() {
            _associationBox.remove(id);
          });
          break;
        }
      case 'rate':
        {
          setState(() {
            _ratesBox.remove(id);
          });
          break;
        }
      default:
        {
          break;
        }
    }
  }

  void deleteAllFromAllDbs() {
    _invoiceBox.removeAll();
    _ratesBox.removeAll();
    _clientsBox.removeAll();
    _consultantsBox.removeAll();
    _associationBox.removeAll();
  }

  seedDbs() {}

  getSelectedClientLabel() {
    return getSelectedClient()!.name;
  }

  getSelectedConsultantLabel() {
    return getSelectedConsultant()!.name;
  }

  getSelectedPayRateLabel() {
    return getSelectedPayRate()!.rate;
  }
}
