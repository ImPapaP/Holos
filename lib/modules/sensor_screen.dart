import 'package:flutter/material.dart';

import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/ble_sensor.dart';
import '../widgets/big_tile.dart';
import '../core/l10n.dart';
import '../core/app_state.dart';
import '../widgets/lang_toggle.dart';

/// Gas, smoke and heat alerts from the Gabay ESP32 sensor over Bluetooth,
/// for users who cannot smell or feel heat.
class SensorScreen extends StatefulWidget {
  const SensorScreen({super.key});

  @override
  State<SensorScreen> createState() => _SensorScreenState();
}

class _SensorScreenState extends State<SensorScreen> {
  static const gasLimit = 600; // raw MQ-2 reading; calibrate per sensor
  static const hotLimit = 50.0; // °C

  late final BleSensor _ble = BleSensor(onData: _onData, onStatus: _onStatus);
  String _status = L('Not connected');
  int? _gas;
  double? _temp;
  DateTime _lastAlert = DateTime.fromMillisecondsSinceEpoch(0);

  void _onStatus(String s) {
    if (mounted) setState(() => _status = s);
  }

  void _onData(int gas, double temp) {
    if (!mounted) return;
    setState(() {
      _gas = gas;
      _temp = temp;
    });
    final now = DateTime.now();
    if (now.difference(_lastAlert).inSeconds < 10) return;
    if (gas > gasLimit) {
      _lastAlert = now;
      _alert('gas');
    } else if (temp > hotLimit) {
      _lastAlert = now;
      _alert('hot');
    }
  }

  void _alert(String kind) {
    Output.notify(S.t(kind), kind == 'hot' ? Haptics.hot : Haptics.gas,
        color: kind == 'hot' ? const Color(0xFFE07B00) : GabayColors.danger);
  }

  @override
  void dispose() {
    _ble.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(actions: const [LangToggle()], title: Text(L('Sensor Alerts'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
              L('For people who cannot smell gas or smoke, or cannot feel heat. Connect the Gabay ESP32 sensor (MQ-2 gas/smoke + temperature) by Bluetooth.'),
              style: TextStyle(color: GabayColors.mute, fontSize: 17)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _ble.connected ? _ble.disconnect().then((_) => _onStatus(L('Not connected'))) : _ble.connect(),
            child: Text(_ble.connected ? L('Disconnect sensor') : L('Connect sensor')),
          ),
          const SizedBox(height: 10),
          Text(_status, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _reading(L('Gas / smoke'), _gas?.toString() ?? '--', (_gas ?? 0) > gasLimit)),
              const SizedBox(width: 10),
              Expanded(child: _reading(L('Temperature'), _temp == null ? '--' : '${_temp!.toStringAsFixed(1)}°C', (_temp ?? 0) > hotLimit)),
            ],
          ),
          SectionLabel(L('Test alerts (no sensor needed)')),
          BigTile(title: L('Test: Gas leak'), subtitle: L('LPG detected in the kitchen'), icon: Icons.local_fire_department, onTap: () => _alert('gas')),
          const SizedBox(height: 10),
          BigTile(title: L('Test: Smoke'), subtitle: L('Smoke or burning food'), icon: Icons.cloud, onTap: () => _alert('smoke')),
          const SizedBox(height: 10),
          BigTile(title: L('Test: Hot surface'), subtitle: L('Water or pan above safe temperature'), icon: Icons.thermostat, onTap: () => _alert('hot')),
        ],
      ),
    ));
  }

  Widget _reading(String label, String value, bool warn) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: warn ? GabayColors.danger : GabayColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: warn ? Colors.white70 : GabayColors.mute)),
            Text(value, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
