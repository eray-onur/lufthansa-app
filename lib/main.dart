import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:http/http.dart' as http;
// Background process after app termination is still WIP(Work in Progress).
// NOT: 401 Status Code aliniyor, access token degismeli.
String apiKey = "c2zqxfpz7y8uc6bhx7d2vcrd";
String accessToken = "5rnxsv7yh7u5thsr9gymgt3k";
String secret = "h3WbRTZRHk";

const textStyle = TextStyle(fontSize: 16.0, fontWeight: FontWeight.w300);
const boldStyle = TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700);

const EVENTS_KEY = "fetch_events";

/// This "Headless Task" is run when app is terminated.
void backgroundFetchHeadlessTask() async {
  print('[BackgroundFetch] Headless event received.');

  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Read fetch_events from SharedPreferences
  List<String> events = [];
  String json = prefs.getString(EVENTS_KEY);
  if (json != null) {
    events = jsonDecode(json).cast<String>();
  }
  // Add new event.
  events.insert(0, new DateTime.now().toString() + ' [Headless]');
  displayNotification();
  // Persist fetch events in SharedPreferences
  prefs.setString(EVENTS_KEY, jsonEncode(events));
  BackgroundFetch.finish();
}

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

final List<Notification> notifications = [];

void displayNotification() async {
  print("On to display a notification..");
  var androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'first_channel', 'Flight App', 'your channel description',
      importance: Importance.Max, priority: Priority.High, ticker: 'ticker');
  var iOSPlatformChannelSpecifics = IOSNotificationDetails();
  var platformChannelSpecifics = NotificationDetails(
      androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
      0, 'Flight Carrier', "Carrier you're looking for is about to depart!",
      platformChannelSpecifics,
      payload: 'FlightCarrier');
}

void main(){
  runApp(new MyApp());
  // Register to receive BackgroundFetch events after app is terminated.
  // Requires {stopOnTerminate: false, enableHeadless: true}
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flight App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        splashColor: Colors.lightBlueAccent,
      ),
      home: MyHomePage(title: 'Flight App'),
    );
  }
}
Map<String, String> requestHeaders = {
  HttpHeaders.contentTypeHeader: "application/json", // or whatever
  HttpHeaders.authorizationHeader: "Bearer $accessToken",
};

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  dynamic data;
  var dataStatus = 0;
  var isLoading = false;
  bool isSearching = false;
  bool isSelected = false;
  String searchParameter = "LH400";

  //
  bool _enabled = true;
  int _status = 0;
  List<String> _events = [];

  //

  final _formKey = GlobalKey<FormState>();

  Future onSelectNotification(String payload) async {
    if (payload != null) {
      debugPrint('notification payload: ' + payload);
    }
    await Navigator.push(
      context,
      new MaterialPageRoute(builder: (context) => MyHomePage()),
    );
  }

  void initializeLocalNotifications() {
    flutterLocalNotificationsPlugin = new FlutterLocalNotificationsPlugin();
// initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
    var initializationSettingsAndroid =
    new AndroidInitializationSettings('app_icon');
    var initializationSettingsIOS = new IOSInitializationSettings(
        onDidReceiveLocalNotification: onDidReceiveLocalNotification);
    var initializationSettings = new InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onSelectNotification: onSelectNotification);
  }

  Future onDidReceiveLocalNotification(int id, String title, String body,
      String payload) async {
    // display a dialog with the notification details, tap ok to go to another page
    showDialog(
      context: context,
      builder: (BuildContext context) =>
      new AlertDialog(
          title: new Text(title),
          content: new Text(body),
          actions: <Widget>[
            FlatButton(
              child: new Text('Ok'),
              onPressed: () async {
                Navigator.of(context, rootNavigator: true).pop();
                await Navigator.push(
                  context,
                  new MaterialPageRoute(
                    builder: (context) => new MyHomePage(),
                  ),
                );
              },
            )
          ]
      ),
    );
  }

  // Clearing the 'shared preferences' registry.
  void clearRegistry() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.clear();
  }

  void fetchFlight() async {
    var data;
    setState(() {
      this.isSearching = true;
    });
    final response = await http.get(
        "https://api.lufthansa.com/v1/operations/flightstatus/$searchParameter/2019-09-06",
        headers: requestHeaders
    );
    if (response.statusCode == 200) {
      data = json.decode(response.body) as dynamic;
      print(data);
    }
    else if (response.statusCode == 401) {
      data = "You are forbidden to use this API. Please change your access token.";
    }
    else
      throw Exception("Failed to load data. This status code was returned instead: ${response.statusCode}");
    setState(() {
      this.isLoading = !isLoading;
      // Getting the status code.
      this.dataStatus = response.statusCode;
      this.data = data;
      this.isSearching = !this.isSearching;
    });
  }
  void saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var savedFlightDate = prefs.getString("SavedFlightDate");
    if (savedFlightDate == null && data != null) {
      prefs.setString(
          "SavedFlightDate", data["ScheduledTimeLocal"]["DateTime"]);
    }
    else
      print("NOPE no can do.");
    print(savedFlightDate);
  }
  void _onBackgroundFetch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // This is the fetch-event callback.
    print('[BackgroundFetch] Event received');
    setState(() {
      _events.insert(0, new DateTime.now().toIso8601String());
    });
    displayNotification();
    // Persist fetch events in SharedPreferences
    prefs.setString(EVENTS_KEY, jsonEncode(_events));
    // IMPORTANT:  You must signal completion of your fetch task or the OS can punish your app
    // for taking too long in the background.
    BackgroundFetch.finish();
  }

  // DO NOT include the function below during the production phase. It's merely to clear
  // the device's registry after quitting and reinitializing the main page.
  @override
  void initState() {
    super.initState();
    clearRegistry();
    initializeLocalNotifications();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Load persisted fetch events from SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String json = prefs.getString(EVENTS_KEY);
    if (json != null) {
      setState(() {
        _events = jsonDecode(json).cast<String>();
      });
    }

    // Configure BackgroundFetch.
    BackgroundFetch.configure(BackgroundFetchConfig(
        minimumFetchInterval: 15,
        enableHeadless: true,
        startOnBoot: true,
        forceReload: false,
      stopOnTerminate: false,
    ), _onBackgroundFetch).then((int status) {
      print('[BackgroundFetch] SUCCESS: $status');
      setState(() {
        _status = status;
      });
    }).catchError((e) {
      print('[BackgroundFetch] ERROR: $e');
      setState(() {
        _status = e;
      });
    });

    // Optionally query the current BackgroundFetch status.
    int status = await BackgroundFetch.status;
    setState(() {
      _status = status;
    });

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
  }
  void _onClickEnable(enabled) {
    setState(() {
      _enabled = enabled;
    });
    if (enabled) {
      BackgroundFetch.start().then((int status) {
        print('[BackgroundFetch] start success: $status');
      }).catchError((e) {
        print('[BackgroundFetch] start FAILURE: $e');
      });
    } else {
      BackgroundFetch.stop().then((int status) {

        print('[BackgroundFetch] stop success: $status');
      });
    }
  }

  void _onClickStatus() async {
    int status = await BackgroundFetch.status;
    print('[BackgroundFetch] status: $status');
    setState(() {
      _status = status;
    });
  }

  void _onClickClear() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove(EVENTS_KEY);
    setState(() {
      _events = [];
    });
  }

  Widget showDate() {
    if(_events.length > 0) {
      return Text("Last received: ${_events[0]}");
    } else return Text("No events yet.");
  }


  Widget showData() {
      if (this.data != null) {
        if(this.dataStatus == 200) {
          return Container(
              padding: EdgeInsets.all(10.0),
              width: 600.0,
              height: 600.0,
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text("Airport Code:", style: boldStyle,),
                          Text("${data["AirportCode"]}", style: textStyle,),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text("Scheduled Time(Local) :", style: boldStyle,),
                          Text("${data["ScheduledTimeLocal"]["DateTime"]}",
                            style: textStyle,),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text("Scheduled Time(UTC) :", style: boldStyle,),
                          Text("${data["ScheduledTimeUTC"]["DateTime"]}",
                            style: textStyle,),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Text("Time Status Definition:", style: boldStyle,),
                          Text("${data["TimeStatus"]["Definition"]}",
                            style: textStyle,),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: CheckboxListTile(
                        activeColor: Colors.blue,
                        checkColor: Colors.greenAccent,
                        title: const Text('Notify when it arrives.'),
                        value: isSelected,
                        onChanged: (b){this._onClickEnable(_enabled);},
                        secondary: const Icon(Icons.hourglass_empty),
                      ),
                    )
                  ],
                ),
              )
          );
        }
        else if(this.dataStatus == 401) {
          return Text("You are forbidden to use this API. Please check your access token.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24.0),);
        }
      }
      else {
          if(this.isSearching == true) {
            return SizedBox(
              width: MediaQuery.of(context).size.width,
              height: 500.0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  SizedBox(
                      height: 150.0,
                      width: 150.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 10.0,
                        backgroundColor: Colors.purple,
                        semanticsLabel: "Please wait...",
                      )
                  ),
                  Padding(padding: EdgeInsets.all(25.0),),
                  Text("Please wait while the data is loading...", style: TextStyle(fontSize: 24.0),)
                ],
              ),
            );
          } else return SizedBox();
      }

    }
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(10.0),
                      child: Text(
                        "Please enter the code that belongs to the required carrier's departure.",
                        style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),),

                    )
                  ),
                  showDate(),
                  Form(
                    key: this._formKey,
                    child: TextFormField(
                      validator: (value) {
                        if (value.isEmpty) {
                          return "Please enter a parameter to the 'Search' section.";
                        }
                        else {
                          this.data = null;
                          fetchFlight();
                          return null;
                        }
                      },
                      onChanged: (val) {
                        print("$searchParameter");
                        this.searchParameter = val;
                      },
                    ),
                  ),
                  RaisedButton(
                    padding: EdgeInsets.symmetric(
                        vertical: 5.0, horizontal: 125.0),
                    color: Colors.blue,
                    textColor: Colors.white,
                    onPressed: () {
                      // Validate returns true if the form is valid, otherwise false.
                      if (_formKey.currentState.validate()) {
                        print("$searchParameter");
                        fetchFlight();
                      }
                    },
                    child: Text('Submit'),
                  ),
                ],
              ),
              showData(),
              FlatButton(onPressed: (){
                _onClickEnable(_enabled);
              }, child: Text("Click for enabling the background fetch test!"),)
            ],
          ),
        ), // This trailing comma makes auto-formatting nicer for build methods.
      );
    }
  }
