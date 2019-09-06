import 'package:flutter/material.dart';
class FlightWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width,
      child: Text("This is the example widget."),
    );
  }
}
