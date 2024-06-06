import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '사육장 모니터링',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'baemin',
      ),
      home: MonitoringPage(),
    );
  }
}

class MonitoringPage extends StatefulWidget {
  @override
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  double targetTemperature = 25.0;
  double targetHumidity = 50.0;

  double currentTemperature = 24.0;
  double currentHumidity = 48.0;
  double soilMoisture = 40.0;
  double currentWaterLevel = 0.75; // 75% 가정

  bool ledTrigger = false;
  bool currentFan = false;
  bool currentHeater = false;
  bool currentHumidifier = false;

  TimeOfDay? ledStartTime;
  TimeOfDay? ledEndTime;

  TextEditingController temperatureController = TextEditingController();
  TextEditingController humidityController = TextEditingController();

  final DatabaseReference databaseReference = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    temperatureController.text = targetTemperature.toString();
    humidityController.text = targetHumidity.toString();
    _getDataFromDatabase();
  }

  @override
  void dispose() {
    temperatureController.dispose();
    humidityController.dispose();
    super.dispose();
  }

  void _getDataFromDatabase() {
    // 현재 온도 가져오기
    databaseReference.child('temp').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        currentTemperature = data != null ? double.parse(data.toString()) : 24.0;
      });
    }, onError: (error) {
      print('Error getting temperature from database: $error');
    });

    // 현재 습도 가져오기
    databaseReference.child('humidity').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        currentHumidity = data != null ? double.parse(data.toString()) : 48.0;
      });
    }, onError: (error) {
      print('Error getting humidity from database: $error');
    });

    // 토양 습도 가져오기
    databaseReference.child('humidity_GND').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        soilMoisture = data != null ? double.parse(data.toString()) : 40.0;
      });
    }, onError: (error) {
      print('Error getting soil moisture from database: $error');
    });

    // 물통 물높이 가져오기
    databaseReference.child('water_gauge').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        double waterLevel = data != null ? double.parse(data.toString()) : 0.75;
        currentWaterLevel = waterLevel.clamp(0.0, 1.0);
      });
    }, onError: (error) {
      print('Error getting water gauge from database: $error');
    });

    // 팬 상태 가져오기
    databaseReference.child('current_fan').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        currentFan = data != null ? data as bool : false;
      });
    }, onError: (error) {
      print('Error getting fan status from database: $error');
    });

    // 히터 상태 가져오기
    databaseReference.child('current_heater').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        currentHeater = data != null ? data as bool : false;
      });
    }, onError: (error) {
      print('Error getting heater status from database: $error');
    });

    // 가습기 상태 가져오기
    databaseReference.child('current_humidifier').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        currentHumidifier = data != null ? data as bool : false;
      });
    }, onError: (error) {
      print('Error getting humidifier status from database: $error');
    });

    // LED 트리거 상태 가져오기
    databaseReference.child('led_trigger').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        ledTrigger = data != null ? data as bool : false;
      });
    }, onError: (error) {
      print('Error getting LED trigger from database: $error');
    });

    // LED 시작 시간 가져오기
    databaseReference.child('led_start_time').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        ledStartTime = data != null ? _parseTimeOfDay(data.toString()) : null;
      });
    }, onError: (error) {
      print('Error getting LED start time from database: $error');
    });

    // LED 종료 시간 가져오기
    databaseReference.child('led_end_time').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      setState(() {
        ledEndTime = data != null ? _parseTimeOfDay(data.toString()) : null;
      });
    }, onError: (error) {
      print('Error getting LED end time from database: $error');
    });
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final format = DateFormat.Hm();
    final dateTime = format.parse(time);
    return TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
  }

  String _formatTimeOfDay24(TimeOfDay time) {
    final now = DateTime.now();
    final dateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('HH:mm').format(dateTime);
  }

  void _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? ledStartTime ?? TimeOfDay.now() : ledEndTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != (isStartTime ? ledStartTime : ledEndTime)) {
      setState(() {
        if (isStartTime) {
          ledStartTime = picked;
          databaseReference.child('led_start_time').set(_formatTimeOfDay24(picked));
        } else {
          ledEndTime = picked;
          databaseReference.child('led_end_time').set(_formatTimeOfDay24(picked));
        }
      });
    }
  }

  void updateSettings(bool isTemperature) {
    if (isTemperature) {
      double newTargetTemperature = double.tryParse(temperatureController.text) ?? targetTemperature;
      if (newTargetTemperature > 50) {
        showErrorDialog('50도 보다 낮은 값을 입력하세요');
        temperatureController.text = targetTemperature.toString();
        return;
      }
      setState(() {
        targetTemperature = newTargetTemperature;
        databaseReference.child('target_temp').set(targetTemperature);
      });
    } else {
      double newTargetHumidity = double.tryParse(humidityController.text) ?? targetHumidity;
      if (newTargetHumidity > 100) {
        showErrorDialog('100% 보다 낮은 값을 입력하세요');
        humidityController.text = targetHumidity.toString();
        return;
      }
      setState(() {
        targetHumidity = newTargetHumidity;
        databaseReference.child('target_humidity').set(targetHumidity);
      });
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('오류'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _applyExampleSettings(Map<String, dynamic> settings) {
    setState(() {
      targetTemperature = settings['targetTemperature'];
      targetHumidity = settings['targetHumidity'];
      ledStartTime = _parseTimeOfDay(settings['ledStartTime']);
      ledEndTime = _parseTimeOfDay(settings['ledEndTime']);
      temperatureController.text = targetTemperature.toString();
      humidityController.text = targetHumidity.toString();

      databaseReference.child('target_temp').set(targetTemperature);
      databaseReference.child('target_humidity').set(targetHumidity);
      databaseReference.child('led_start_time').set(settings['ledStartTime']);
      databaseReference.child('led_end_time').set(settings['ledEndTime']);
    });
  }

  void _showExampleDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('예시 데이터 선택'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text('예시 데이터 1'),
                subtitle: Text('목표 온도: 22도, 목표 습도: 55%, LED 켜짐: 08:00, LED 꺼짐: 18:00'),
                onTap: () {
                  _applyExampleSettings({
                    'targetTemperature': 22.0,
                    'targetHumidity': 55.0,
                    'ledStartTime': '08:00',
                    'ledEndTime': '18:00',
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('예시 데이터 2'),
                subtitle: Text('목표 온도: 24도, 목표 습도: 60%, LED 켜짐: 07:00, LED 꺼짐: 19:00'),
                onTap: () {
                  _applyExampleSettings({
                    'targetTemperature': 24.0,
                    'targetHumidity': 60.0,
                    'ledStartTime': '07:00',
                    'ledEndTime': '19:00',
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                title: Text('예시 데이터 3'),
                subtitle: Text('목표 온도: 20도, 목표 습도: 50%, LED 켜짐: 09:00, LED 꺼짐: 17:00'),
                onTap: () {
                  _applyExampleSettings({
                    'targetTemperature': 20.0,
                    'targetHumidity': 50.0,
                    'ledStartTime': '09:00',
                    'ledEndTime': '17:00',
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget sensorBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10.0),
        margin: EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade200,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(label, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.normal, fontSize: 20)),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget waterLevelIndicator() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('물통', style: TextStyle(fontWeight: FontWeight.w100, fontSize: 20,)),
          SizedBox(height: 8),
          Stack(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: currentWaterLevel,
                  minHeight: 40,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${(currentWaterLevel * 100).clamp(0, 100).toInt()}%', // 클램프 추가
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget actuatorIndicator(String label, bool isActive) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(10.0),
        margin: EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.shade200,
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Icon(
              Icons.circle,
              color: isActive ? Colors.green : Colors.grey,
              size: 30,
            ),
            SizedBox(height: 5),
            Text(isActive ? "작동중" : "꺼짐", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  void _toggleLED(bool value) {
    setState(() {
      ledTrigger = value;
      databaseReference.child('led_trigger').set(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('스마트 사육장', style: TextStyle(fontFamily: 'baemin', fontSize: 40),),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: _showExampleDataDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("현재 상태", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w100),),
              ],
            ),
            SizedBox(height: 10,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                sensorBox("온도 (섭씨)", "$currentTemperature도"),
                sensorBox("공기 습도", "$currentHumidity%"),
                sensorBox("토양 습도", "$soilMoisture%"),
              ],
            ),
            SizedBox(height: 30),
            waterLevelIndicator(),
            SizedBox(height: 10),
            Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    actuatorIndicator("팬", currentFan),
                    actuatorIndicator("히터", currentHeater),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    actuatorIndicator("가습기", currentHumidifier),
                    actuatorIndicator("LED", ledTrigger),
                  ],
                ),
              ],
            ),
            SizedBox(height: 40),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: temperatureController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '목표 온도 설정 (섭씨)',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => updateSettings(true),
                  child: Text('설정 저장', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: humidityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '목표 습도 설정 (%)',
                      border: OutlineInputBorder(),
                    ),
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => updateSettings(false),
                  child: Text('설정 저장', style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text("LED 상태", style: TextStyle(fontSize: 20)),
                Switch(
                  value: ledTrigger,
                  onChanged: _toggleLED,
                ),
                SizedBox(width: 30,),
                Text("ON", style: TextStyle(fontSize: 20)),
                TextButton(
                  onPressed: () => _selectTime(context, true),
                  child: Text(ledStartTime != null ? ledStartTime!.format(context) : '설정'),
                ),
                Text("OFF", style: TextStyle(fontSize: 20)),
                TextButton(
                  onPressed: () => _selectTime(context, false),
                  child: Text(ledEndTime != null ? ledEndTime!.format(context) : '설정'),
                )],
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
