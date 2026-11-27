import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/theme.dart';

/// Emergency screen. Vibrates SOS, gets the GPS location and opens an SMS
/// to the caregiver with a Google Maps link (the user presses Send).
class SosScreen extends StatefulWidget {
  final String reason;
  final bool countdown;
  const SosScreen({super.key, required this.reason, this.countdown = false});

  static bool _open = false;

  static void trigger({required String reason, bool countdown = false}) {
    if (_open) return;
    final nav = navKey.currentState;
    if (nav == null) return;
    _open = true;
    nav
        .push(MaterialPageRoute(builder: (_) => SosScreen(reason: reason, countdown: countdown)))
        .whenComplete(() => _open = false);
  }

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  Timer? _buzz;
  Timer? _tick;
  Timer? _hold;
  int _left = 10;
  String _status = '';
  String? _mapLink;

  @override
  void initState() {
    super.initState();
    Haptics.play(Haptics.sos);
    Output.speak('SOS. ${widget.reason}', force: true);
    _buzz = Timer.periodic(const Duration(seconds: 4), (_) => Haptics.play(Haptics.sos));
    _getLocation();
    if (widget.countdown) {
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          _sendSms();
        }
      });
    }
  }

  Future<void> _getLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
      setState(() {
        _mapLink = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
        _status = 'Location ready';
      });
    } catch (_) {
      setState(() => _status = 'Could not get location');
    }
  }

  String get _message {
    final who = AppState.I.caregiverName.isEmpty ? '' : '${AppState.I.caregiverName}, ';
    return '${who}SOS from Gabay: ${widget.reason}. I need help.${_mapLink != null ? ' My location: $_mapLink' : ''}';
  }

  Future<void> _sendSms() async {
    final phone = AppState.I.caregiverPhone;
    if (phone.isEmpty) {
      setState(() => _status = 'No caregiver number. Add one in Settings.');
      return;
    }
    final uri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': _message});
    if (!await launchUrl(uri)) setState(() => _status = 'Could not open SMS app');
  }

  Future<void> _call() async {
    final phone = AppState.I.caregiverPhone;
    if (phone.isEmpty) {
      setState(() => _status = 'No caregiver number. Add one in Settings.');
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  void _cancel() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _buzz?.cancel();
    _tick?.cancel();
    _hold?.cancel();
    Haptics.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counting = widget.countdown && _left > 0 && (_tick?.isActive ?? false);
    return Scaffold(
      backgroundColor: GabayColors.danger,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => _hold = Timer(const Duration(milliseconds: 1500), _cancel),
        onLongPressEnd: (_) => _hold?.cancel(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Text('SOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 88, fontWeight: FontWeight.w900, color: Colors.white)),
                Text(widget.reason,
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, color: Colors.white)),
                const SizedBox(height: 12),
                if (counting)
                  Text('Sending SMS to caregiver in $_left s',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white70)),
                const Spacer(),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: () {
                    _tick?.cancel();
                    _sendSms();
                  },
                  icon: const Icon(Icons.sms),
                  label: const Text('Text caregiver now'),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  onPressed: _call,
                  icon: const Icon(Icons.call),
                  label: const Text('Call caregiver'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2)),
                  onPressed: _cancel,
                  child: const Text("Cancel, I'm OK"),
                ),
                const SizedBox(height: 8),
                const Text('Or hold anywhere for 1.5 seconds to cancel',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
