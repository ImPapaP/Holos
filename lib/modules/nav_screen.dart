import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_state.dart';
import '../core/haptics.dart';
import '../core/output.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/heading.dart';
import '../services/test_log.dart';
import '../widgets/big_tile.dart';
import '../core/l10n.dart';
import '../widgets/lang_toggle.dart';

/// Daan: haptic guidance toward a saved place (straight-line direction, not street routing).
/// Facing the right way = soft tick; target on the left/right = left/right pattern; arrived = Gabay pulses.
class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  late final HeadingService _compass = HeadingService(onHeading: (_) {});
  StreamSubscription<Position>? _pos;
  Timer? _guideTimer;
  SavedPlace? _target;
  Position? _here;
  double? _distance;
  double? _bearing;
  double _lastSpokenDist = double.infinity;
  bool _arrived = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _compass.start();
    _startGps();
    _guideTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) => _guide());
  }

  Future<void> _startGps() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _status = L('Location permission denied'));
      return;
    }
    _pos = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2)).listen((p) {
      setState(() {
        _here = p;
        if (_target != null) {
          _distance = Geolocator.distanceBetween(p.latitude, p.longitude, _target!.lat, _target!.lon);
          _bearing = bearingTo(p.latitude, p.longitude, _target!.lat, _target!.lon);
        }
      });
    });
  }

  void _guide() {
    final t = _target, d = _distance, b = _bearing, h = _compass.heading;
    if (t == null || d == null || b == null || h == null) {
      if (mounted) setState(() {});
      return;
    }
    if (d < 15) {
      if (!_arrived) {
        _arrived = true;
        Haptics.play(Haptics.logo);
        final msg = S.lang == Lang.fil ? 'Nandito ka na sa ${t.name}' : 'You have arrived at ${t.name}';
        Output.speak(msg, force: AppState.I.out.voice);
        Output.notify(msg, Haptics.logo, color: GabayColors.ok);
        TestLog.I.log('Daan', 'arrived ${t.name}', score: d);
      }
      setState(() {});
      return;
    }
    _arrived = false;
    final diff = angleDiff(b, h);
    if (diff.abs() <= 20) {
      Haptics.pulse(40, 120); // on course
    } else if (diff > 0) {
      Haptics.play(Haptics.right);
    } else {
      Haptics.play(Haptics.left);
    }
    // Say the distance every 50 m.
    if ((_lastSpokenDist - d).abs() >= 50 || _lastSpokenDist == double.infinity) {
      _lastSpokenDist = d;
      Output.speak(S.lang == Lang.fil ? '${d.round()} metro pa' : '${d.round()} meters to go');
    }
    setState(() {});
  }

  Future<void> _saveHere() async {
    final p = _here ?? await Geolocator.getCurrentPosition();
    if (!mounted) return;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(L('Name this place')),
        content: TextField(controller: ctrl, autofocus: true, decoration: InputDecoration(hintText: L('Home, school, terminal'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(L('Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: Text(L('Save'))),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await AppState.I.savePlaces([...AppState.I.places, SavedPlace(name, p.latitude, p.longitude)]);
    Haptics.play(Haptics.start);
    Output.speak('Saved $name', force: true);
    setState(() {});
  }

  void _go(SavedPlace p) {
    setState(() {
      _target = p;
      _arrived = false;
      _lastSpokenDist = double.infinity;
      if (_here != null) {
        _distance = Geolocator.distanceBetween(_here!.latitude, _here!.longitude, p.lat, p.lon);
        _bearing = bearingTo(_here!.latitude, _here!.longitude, p.lat, p.lon);
      }
    });
    Output.speak(S.lang == Lang.fil ? 'Gagabayan ka papunta sa ${p.name}' : 'Guiding you to ${p.name}', force: true);
  }

  @override
  void dispose() {
    _compass.stop();
    _pos?.cancel();
    _guideTimer?.cancel();
    Haptics.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _compass.heading;
    final diff = (_bearing != null && h != null) ? angleDiff(_bearing!, h) : null;
    final onCourse = diff != null && diff.abs() <= 20;
    return ListenableBuilder(listenable: AppState.I, builder: (context, _) => Scaffold(
      appBar: AppBar(actions: const [LangToggle()], title: const Text('Daan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(L('Guides you toward a saved place using vibration. It points in a straight line, so follow sidewalks and use your cane.'),
              style: TextStyle(color: GabayColors.mute, fontSize: 16)),
          const SizedBox(height: 16),
          if (_target != null) ...[
            // Visual helper: a big arrow that points toward the place.
            Container(
              height: 260,
              decoration: BoxDecoration(color: GabayColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: onCourse ? GabayColors.ok : GabayColors.line, width: 4)),
              child: Center(
                child: diff == null
                    ? Text(S.lang == Lang.fil ? 'Hinahanap ang direksyon…' : 'Finding direction…', style: TextStyle(fontSize: 20, color: GabayColors.mute))
                    : Transform.rotate(
                        angle: diff * pi / 180,
                        child: Icon(Icons.navigation, size: 190, color: _arrived ? GabayColors.ok : (onCourse ? GabayColors.ok : GabayColors.accent)),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _arrived
                    ? (S.lang == Lang.fil ? 'Nandito ka na' : 'You have arrived')
                    : '${_target!.name} · ${_distance == null ? '…' : '${_distance!.round()} m'}${diff == null ? '' : (onCourse ? (S.lang == Lang.fil ? ' · diretso' : ' · straight ahead') : (diff > 0 ? (S.lang == Lang.fil ? ' · kumanan' : ' · turn right') : (S.lang == Lang.fil ? ' · kumaliwa' : ' · turn left')))}',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: GabayColors.ink),
              ),
            ),
            if (_here != null && _here!.accuracy > 15)
              Text(S.lang == Lang.fil ? 'Mga ${_here!.accuracy.round()} m ang katumpakan ng GPS. Pumunta sa maluwag na lugar para mas tumpak.' : 'GPS accuracy is about ${_here!.accuracy.round()} m. Move to an open area for better guidance.', style: TextStyle(color: GabayColors.mute, fontSize: 15)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => setState(() => _target = null), child: Text(L('Stop guiding'))),
          ],
          SectionLabel(L('Saved places')),
          if (AppState.I.places.isEmpty) Text(L('No saved places yet.'), style: TextStyle(color: GabayColors.mute)),
          for (final p in AppState.I.places) ...[
            BigTile(
              title: p.name,
              subtitle: _here == null ? L('Tap to be guided here') : S.lang == Lang.fil ? '${Geolocator.distanceBetween(_here!.latitude, _here!.longitude, p.lat, p.lon).round()} m ang layo · pindutin para pumunta' : '${Geolocator.distanceBetween(_here!.latitude, _here!.longitude, p.lat, p.lon).round()} m away · tap to go',
              icon: Icons.place,
              selected: identical(p, _target),
              onTap: () => _go(p),
            ),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(onPressed: _saveHere, icon: const Icon(Icons.add_location_alt), label: Text(L('Save this place'))),
          if (AppState.I.places.isNotEmpty) ...[
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => AppState.I.savePlaces([]).then((_) => setState(() {})), child: Text(L('Delete all saved places'))),
          ],
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_status, style: TextStyle(color: GabayColors.danger))),
        ],
      ),
    ));
  }
}
