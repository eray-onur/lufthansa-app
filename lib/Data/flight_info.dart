import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

String apiKey = "c2zqxfpz7y8uc6bhx7d2vcrd";
String accessToken = "9nwtnr7gkk3ka9d2jsaer2ep";
String secret = "h3WbRTZRHk";
Map<String, String> requestHeaders = {
  HttpHeaders.contentTypeHeader: "application/json", // or whatever
  HttpHeaders.authorizationHeader: "Bearer $accessToken",
};

class FlightInfo {
  final int airportCode;
  final DateTime scheduledTimeLocal;
  final DateTime scheduledTimeUTC;
  dynamic timeStatus;
  dynamic terminal;

  final String searchParameter = "LH400";

  FlightInfo({this.airportCode,
    this.scheduledTimeLocal,
    this.scheduledTimeUTC,
    this.timeStatus,
    this.terminal});

  factory FlightInfo.fromJson(Map<String,dynamic> json) {
    return FlightInfo(
      airportCode: json['AirportCode'] as int,
      scheduledTimeLocal: json['ScheduledTimeLocal'] as DateTime,
      scheduledTimeUTC: json['ScheduledTimeUTC'] as DateTime,
      timeStatus: json['TimeStatus'] as dynamic,
      terminal: json['Terminal'] as dynamic,
    );
  }
}
List<FlightInfo> parseFlightInfo(String responseBody) {
  final parsed = json.decode(responseBody).cast<Map<String,dynamic>>();
  return parsed.map<FlightInfo>((json) => FlightInfo.fromJson(json)).toList();
}
Future<List<FlightInfo>> fetchFlightInfo(http.Client cli) async {
  final response = await cli.get("https://api.lufthansa.com/v1/operations/flightstatus/LH400/2019-09-06",
      headers: requestHeaders);
  print("LOOK HERE: ${response.body}");
  return compute(parseFlightInfo ,response.body);
}