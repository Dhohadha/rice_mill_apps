import 'dart:async';
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/meter_data.dart';

class MqttService {
  final MqttServerClient client;
  final _dataController = StreamController<MeterData>.broadcast();
  Stream<MeterData> get dataStream => _dataController.stream;

  MqttService() : client = MqttServerClient('broker.emqx.io', 'rice_mill_lite_${DateTime.now().millisecondsSinceEpoch}') {
    client.port = 1883;
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;
  }

  Future<void> connect() async {
    try {
      await client.connect();
    } catch (e) {
      print('MQTT Exception: $e');
      client.disconnect();
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT Connected');
      // Subscribe to all mill topics
      client.subscribe('EMS1/data', MqttQos.atMostOnce);
      client.subscribe('EMS/+/data', MqttQos.atMostOnce);

      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final data = jsonDecode(pt);
          // Standardize payload to match MeterData model
          // If the topic is EMS/deviceID/data, we might need to extract deviceID
          String deviceId = data['deviceId'] ?? 'RICE_MILL_001';
          if (c[0].topic.startsWith('EMS/')) {
            deviceId = c[0].topic.split('/')[1];
          }

          final meterData = MeterData(
            deviceId: deviceId,
            kVATotal: (data['KVA'] ?? data['kva'] ?? 0.0).toDouble(),
            kWTotal: (data['KW'] ?? data['kw'] ?? 0.0).toDouble(),
            pfAvg: (data['PF'] ?? data['pf'] ?? 0.0).toDouble(),
            kWh: (data['KWH'] ?? data['kwh'] ?? 0.0).toDouble(),
          );
          _dataController.add(meterData);
        } catch (e) {
          print('Error parsing MQTT payload: $e');
        }
      });
    } else {
      print('MQTT connection failed - status is ${client.connectionStatus}');
      client.disconnect();
    }
  }

  void _onConnected() => print('MQTT Connected callback');
  void _onDisconnected() => print('MQTT Disconnected callback');
  void _onSubscribed(String topic) => print('MQTT Subscribed: $topic');

  void disconnect() {
    client.disconnect();
    _dataController.close();
  }
}
