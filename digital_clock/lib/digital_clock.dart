// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:digital_clock/digital_clock_maker.dart';
import 'package:digital_clock/get_google.dart';
import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/semantics.dart';
import 'package:vector_math/vector_math_64.dart' show radians;
import 'package:flutter/services.dart' show rootBundle;

/// Total distance travelled by a minute hand.
final radiansPerTick = radians(360 / 60);

/// A basic digital clock.
///
/// You can add more animations to make it better!
class DigitalClock extends StatefulWidget {
  const DigitalClock(this.model);

  final ClockModel model;

  @override
  _DigitalClockState createState() => _DigitalClockState();
}

class _DigitalClockState extends State<DigitalClock> {
  var _now = DateTime.now(), customTheme;
  Timer _timer, _timer1, _timer2, _timer3, _timer4;
  DateTime _dateTime = DateTime.now();
  Map timeMap = {},
      startingPoint = {},
      nextPoint = {},
      otherMap = {},
      starter = {};
  List<int> free = [0, 0];
  bool is24Format = true, isTellingNextTime = false;

  @override
  void initState() {
    super.initState();
    starter = GetGoogle().getGoogle();
    otherMap = new Map.unmodifiable(new Map.fromIterable(
        List.generate(93, (index) => index),
        key: (v) => (v + 1).toString(),
        value: (v) => new List<double>.from([37.0, 37.0])));
    widget.model.addListener(_updateModel);

    parseJsonFromAssets().then((onValue) {
      timeMap = new Map<String, dynamic>.unmodifiable(onValue);
    }).then((v) {
      // Set the initial values.
      _updateModel();
      _initiateTimeMachine(firstLaunch: true);
    });
  }

  @override
  void didUpdateWidget(DigitalClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer1?.cancel();
    _timer2?.cancel();
    _timer3?.cancel();
    _timer4?.cancel();
    widget.model.removeListener(_updateModel);
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      if (!isTellingNextTime) is24Format = widget.model.is24HourFormat;
    });
  }

  Future<Map<String, dynamic>> parseJsonFromAssets() async {
    return rootBundle
        .loadString('mapFiles/time.json')
        .then((jsonStr) => jsonDecode(jsonStr));
  }

  void _freeHands() {
    free[0] = free[1] = 1;
    setState(() {});
  }

  void _initiateTimeMachine({bool firstLaunch = false}) {
    _now = DateTime.now();
    isTellingNextTime = false;

    if ((_now.second > 0 && _now.second <= 13) ||
        (_now.second > 24 && _now.second <= 35) ||
        (_now.second > 45 && _now.second <= 57)) {
      setState(() {
        free[0] = free[1] = 0;
        List<String> hourList =
                DateFormat(is24Format ? 'HH' : 'hh').format(_now).split(""),
            minuteList = DateFormat('mm').format(_now).split("");
        nextPoint['next'] = new Map.unmodifiable({
          "other": new Map.unmodifiable(otherMap),
          "time1": new Map.unmodifiable(timeMap["time"][hourList[0]]),
          "time2": new Map.unmodifiable(timeMap["time"][hourList[1]]),
          "time3": new Map.unmodifiable(timeMap["time"][minuteList[0]]),
          "time4": new Map.unmodifiable(timeMap["time"][minuteList[1]])
        });
      });
      _timer1 = Timer(
        Duration(
                seconds: (_now.second > 0 && _now.second <= 13)
                    ? 14
                    : (_now.second > 24 && _now.second <= 35) ? 36 : 58) -
            Duration(seconds: _now.second),
        _initiateTimeMachine,
      );
    } else if ((_now.second >= 14 && _now.second <= 24) ||
        (_now.second >= 36 && _now.second <= 45)) {
      setState(() {
        nextPoint['next'] = new Map.unmodifiable(
            timeMap["animate" + (new Random().nextInt(2)).toString()]);

        // To avoid the conflict of the free hands with the Showing time.
        if ((_now.second >= 36 && _now.second <= 41) ||
            (_now.second >= 14 && _now.second < 20))
          _timer2 = Timer(Duration(seconds: 4, milliseconds: 400), _freeHands);
      });

      setState(() {});

      _timer3 = Timer(
          Duration(
                  seconds: (_now.second >= 14 && _now.second <= 24) ? 25 : 46) -
              Duration(seconds: DateTime.now().second),
          _initiateTimeMachine);
    } else {
      setState(() {
        free[0] = free[1] = 0;
        isTellingNextTime = true;
        _dateTime = _now.add(Duration(seconds: 30));

        List<String> hourList = DateFormat(is24Format ? 'HH' : 'hh')
                .format(_dateTime)
                .split(""),
            minuteList = DateFormat('mm').format(_dateTime).split("");

        nextPoint['next'] = new Map.unmodifiable({
          "other": new Map.unmodifiable(otherMap),
          "time1": new Map.unmodifiable(timeMap["time"][hourList[0]]),
          "time2": new Map.unmodifiable(timeMap["time"][hourList[1]]),
          "time3": new Map.unmodifiable(timeMap["time"][minuteList[0]]),
          "time4": new Map.unmodifiable(timeMap["time"][minuteList[1]])
        });
      });
      _timer4 =
          Timer(Duration(seconds: 4, milliseconds: 400), _initiateTimeMachine);
    }
  }

  @override
  Widget build(BuildContext context) {
    // There are many ways to apply themes to your clock.
    customTheme = Theme.of(context).brightness == Brightness.light
        ? Theme.of(context).copyWith(
            primaryColor: Colors.grey[200], // Boundary of Small Clocks
            highlightColor:
                Colors.black54, // Background Color when showing time
            focusColor: Colors.black26, // Color when showing time
            accentColor: Colors.black) // Animation Color
        : Theme.of(context).copyWith(
            primaryColor: Colors.grey[800],
            highlightColor: Colors.white54,
            focusColor: Colors.white24,
            accentColor: Colors.white);

    return Semantics.fromProperties(
      properties: SemanticsProperties(label: 'Digital clock with time.'),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: <Widget>[
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("1"),
                getSimpleClock("2"),
                getSimpleClock("3"),
                getSimpleClock("4"),
                getSimpleClock("5"),
                getSimpleClock("6"),
                getSimpleClock("7"),
                getSimpleClock("8"),
                getSimpleClock("9"),
                getSimpleClock("10"),
                getSimpleClock("11"),
                getSimpleClock("12"),
                getSimpleClock("13"),
                getSimpleClock("14"),
                getSimpleClock("15"),
                getSimpleClock("16"),
                getSimpleClock("17")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("18"),
                getSimpleClock("19"),
                getSimpleClock("20"),
                getSimpleClock("21"),
                getSimpleClock("22"),
                getSimpleClock("23"),
                getSimpleClock("24"),
                getSimpleClock("25"),
                getSimpleClock("26"),
                getSimpleClock("27"),
                getSimpleClock("28"),
                getSimpleClock("29"),
                getSimpleClock("30"),
                getSimpleClock("31"),
                getSimpleClock("32"),
                getSimpleClock("33"),
                getSimpleClock("34")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("35"),
                getSimpleClock("36"),
                // first time
                getSimpleClock("1", key: "time1"),
                getSimpleClock("2", key: "time1"),
                getSimpleClock("3", key: "time1"),
                // second time
                getSimpleClock("1", key: "time2"),
                getSimpleClock("2", key: "time2"),
                getSimpleClock("3", key: "time2"),
                // middle
                getSimpleClock("37"),
                // third time
                getSimpleClock("1", key: "time3"),
                getSimpleClock("2", key: "time3"),
                getSimpleClock("3", key: "time3"),
                // fourth time
                getSimpleClock("1", key: "time4"),
                getSimpleClock("2", key: "time4"),
                getSimpleClock("3", key: "time4"),
                // boundary
                getSimpleClock("38"),
                getSimpleClock("39")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("40"),
                getSimpleClock("41"),
                // first time
                getSimpleClock("4", key: "time1"),
                getSimpleClock("5", key: "time1"),
                getSimpleClock("6", key: "time1"),
                // second time
                getSimpleClock("4", key: "time2"),
                getSimpleClock("5", key: "time2"),
                getSimpleClock("6", key: "time2"),
                // middle
                getSimpleClock("42"),
                // third time
                getSimpleClock("4", key: "time3"),
                getSimpleClock("5", key: "time3"),
                getSimpleClock("6", key: "time3"),
                // fourth time
                getSimpleClock("4", key: "time4"),
                getSimpleClock("5", key: "time4"),
                getSimpleClock("6", key: "time4"),
                // boundary
                getSimpleClock("43"),
                getSimpleClock("44")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("45"),
                getSimpleClock("46"),
                // first time
                getSimpleClock("7", key: "time1"),
                getSimpleClock("8", key: "time1"),
                getSimpleClock("9", key: "time1"),
                // second time
                getSimpleClock("7", key: "time2"),
                getSimpleClock("8", key: "time2"),
                getSimpleClock("9", key: "time2"),
                // middle
                getSimpleClock("47"),
                // third time
                getSimpleClock("7", key: "time3"),
                getSimpleClock("8", key: "time3"),
                getSimpleClock("9", key: "time3"),
                // fourth time
                getSimpleClock("7", key: "time4"),
                getSimpleClock("8", key: "time4"),
                getSimpleClock("9", key: "time4"),
                // boundary
                getSimpleClock("48"),
                getSimpleClock("49")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("50"),
                getSimpleClock("51"),
                // first time
                getSimpleClock("10", key: "time1"),
                getSimpleClock("11", key: "time1"),
                getSimpleClock("12", key: "time1"),
                // second time
                getSimpleClock("10", key: "time2"),
                getSimpleClock("11", key: "time2"),
                getSimpleClock("12", key: "time2"),
                // middle
                getSimpleClock("52"),
                // third time
                getSimpleClock("10", key: "time3"),
                getSimpleClock("11", key: "time3"),
                getSimpleClock("12", key: "time3"),
                // fourth time
                getSimpleClock("10", key: "time4"),
                getSimpleClock("11", key: "time4"),
                getSimpleClock("12", key: "time4"),
                // boundary
                getSimpleClock("53"),
                getSimpleClock("54")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("55"),
                getSimpleClock("56"),
                // first time
                getSimpleClock("13", key: "time1"),
                getSimpleClock("14", key: "time1"),
                getSimpleClock("15", key: "time1"),
                // second time
                getSimpleClock("13", key: "time2"),
                getSimpleClock("14", key: "time2"),
                getSimpleClock("15", key: "time2"),
                // middle
                getSimpleClock("57"),
                // third time
                getSimpleClock("13", key: "time3"),
                getSimpleClock("14", key: "time3"),
                getSimpleClock("15", key: "time3"),
                // fourth time
                getSimpleClock("13", key: "time4"),
                getSimpleClock("14", key: "time4"),
                getSimpleClock("15", key: "time4"),
                // boundary
                getSimpleClock("58"),
                getSimpleClock("59")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("60"),
                getSimpleClock("61"),
                getSimpleClock("62"),
                getSimpleClock("63"),
                getSimpleClock("64"),
                getSimpleClock("65"),
                getSimpleClock("66"),
                getSimpleClock("67"),
                getSimpleClock("68"),
                getSimpleClock("69"),
                getSimpleClock("70"),
                getSimpleClock("71"),
                getSimpleClock("72"),
                getSimpleClock("73"),
                getSimpleClock("74"),
                getSimpleClock("75"),
                getSimpleClock("76")
              ],
            ),
          ),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                getSimpleClock("77"),
                getSimpleClock("78"),
                getSimpleClock("79"),
                getSimpleClock("80"),
                getSimpleClock("81"),
                getSimpleClock("82"),
                getSimpleClock("83"),
                getSimpleClock("84"),
                getSimpleClock("85"),
                getSimpleClock("86"),
                getSimpleClock("87"),
                getSimpleClock("88"),
                getSimpleClock("89"),
                getSimpleClock("90"),
                getSimpleClock("91"),
                getSimpleClock("92"),
                getSimpleClock("93")
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _getStatus(String key, String id) {
    return nextPoint != null &&
        nextPoint.containsKey("next") &&
        nextPoint["next"].containsKey(key);
  }

  Color _getColor(String key, String id) {
    if (_getStatus(key, id)) {
      if (nextPoint['next'][key][id][0] == 37.0 &&
          nextPoint['next'][key][id][1] == 37.0)
        return customTheme.highlightColor;
      else
        return customTheme.accentColor;
    } else {
      if (starter[key][id][0] == 37.0 && starter[key][id][1] == 37.0)
        return customTheme.focusColor;
      else
        return customTheme.accentColor;
    }
  }

  Widget getSimpleClock(String id, {String key = "other"}) {
    return DigitalClockMaker(
      primaryColor: customTheme.primaryColor,
      highlightColor: _getColor(key, id),
      accentColor: _getColor(key, id),
      blackMin: _getStatus(key, id)
          ? nextPoint['next'][key][id][0]
          : starter[key][id][0],
      blueMin: _getStatus(key, id)
          ? nextPoint['next'][key][id][1]
          : starter[key][id][1],
      freeBlack: free[0],
      freeBlue: free[1],
    );
  }
}
