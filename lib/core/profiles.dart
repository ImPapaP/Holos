import 'package:flutter/material.dart';

enum Profile { blind, deaf, deafblind, neuro, loss }

enum Module { sight, sweep, touch, read, scene, color, peso, nav, sound, talk, calm, sensor, sos }

/// Which senses an alert is delivered through for a profile.
class Outputs {
  final bool voice;
  final bool vibration;
  final bool visual;
  const Outputs({required this.voice, required this.vibration, required this.visual});
}

class ProfileInfo {
  final String name;
  final String desc;
  final Outputs out;
  final List<Module> recommended;
  const ProfileInfo(this.name, this.desc, this.out, this.recommended);
}

const Map<Profile, ProfileInfo> profiles = {
  Profile.blind: ProfileInfo('Blind or low vision', 'Voice + vibration',
      Outputs(voice: true, vibration: true, visual: false), [Module.sight, Module.sweep, Module.touch, Module.read, Module.scene, Module.nav, Module.color, Module.peso, Module.sos]),
  Profile.deaf: ProfileInfo('Deaf or hard of hearing', 'Screen alerts + vibration',
      Outputs(voice: false, vibration: true, visual: true), [Module.sound, Module.sos]),
  Profile.deafblind: ProfileInfo('Deafblind', 'Vibration only',
      Outputs(voice: false, vibration: true, visual: false),
      [Module.sight, Module.sweep, Module.sound, Module.talk, Module.nav, Module.peso, Module.sos]),
  Profile.neuro: ProfileInfo('Sensory sensitive', 'Autism, ADHD, anxiety: gentle alerts + vibration',
      Outputs(voice: false, vibration: true, visual: true), [Module.calm, Module.sos]),
  Profile.loss: ProfileInfo('Lost smell or touch', 'Voice + screen alerts + vibration',
      Outputs(voice: true, vibration: true, visual: true), [Module.sensor, Module.sos]),
};

class ModuleInfo {
  final String title;
  final String desc;
  final IconData icon;
  const ModuleInfo(this.title, this.desc, this.icon);
}

const Map<Module, ModuleInfo> modules = {
  Module.sight: ModuleInfo('Lakad', 'Walk with obstacle alerts by vibration', Icons.directions_walk),
  Module.sweep: ModuleInfo('Sweep', 'Point the phone to scan around you', Icons.radar),
  Module.touch: ModuleInfo('Touch-explore', 'Slide a finger to feel where things are', Icons.touch_app),
  Module.read: ModuleInfo('Basa', 'Read signs, labels and documents aloud', Icons.document_scanner),
  Module.scene: ModuleInfo('Ilarawan', 'Describe the scene in sentences (online)', Icons.auto_awesome),
  Module.color: ModuleInfo('Kulay', 'Say colors and how bright it is', Icons.palette),
  Module.peso: ModuleInfo('Pera', 'Identify peso bills by sound and vibration', Icons.payments),
  Module.nav: ModuleInfo('Daan', 'Vibration guidance to a saved place', Icons.explore),
  Module.sound: ModuleInfo('Tunog', 'Sound alerts and live captions', Icons.hearing),
  Module.talk: ModuleInfo('Touch Talk', 'Messages delivered as vibration', Icons.vibration),
  Module.calm: ModuleInfo('Kalma', 'Noise monitor and haptic breathing', Icons.self_improvement),
  Module.sensor: ModuleInfo('Sensor Alerts', 'Gas, smoke and heat warnings', Icons.sensors),
  Module.sos: ModuleInfo('SOS', 'Emergency alert to your caregiver', Icons.sos),
};
