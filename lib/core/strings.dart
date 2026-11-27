enum Lang { en, fil }

/// Simple English / Filipino strings for voice and on-screen alerts.
class S {
  static Lang lang = Lang.en;

  static const Map<String, String> _en = {
    'loading': 'Loading detector…',
    'ready': 'Ready. Point the phone ahead.',
    'paused': 'Paused',
    'resumed': 'Resumed',
    'clear': 'Path clear',
    'left': 'on the left',
    'right': 'on the right',
    'center': 'ahead',
    'close': 'close',
    'veryClose': 'very close',
    'object': 'Object',
    'sudden': 'Sudden loud sound nearby',
    'continuous': 'Continuous loud sound. Possible alarm or siren.',
    'gas': 'Gas leak detected. Leave the area and open the windows.',
    'smoke': 'Smoke detected. Check for fire.',
    'hot': 'Hot surface. Do not touch.',
    'noisy': 'It is getting loud. Try a breathing break.',
    'inhale': 'Breathe in',
    'hold': 'Hold',
    'exhale': 'Breathe out',
    'fall': 'Fall detected',
    'sos': 'SOS',
    'snd_horn': 'Car horn nearby',
    'snd_siren': 'Siren nearby',
    'snd_alarm': 'Alarm sounding',
    'snd_explosion': 'Loud bang nearby',
    'snd_scream': 'Someone is screaming',
    'snd_glass': 'Glass breaking',
    'snd_baby': 'Baby crying',
    'snd_doorbell': 'Doorbell',
    'snd_knock': 'Knocking at the door',
    'snd_dog': 'Dog barking',
    'snd_phone': 'Phone ringing',
    'snd_loud': 'Loud sound nearby',
    'speaking': 'Someone is talking',
    'sweep_clear': 'Nothing ahead',
    'read_none': 'No text found. Hold the phone closer and try again.',
    'reading': 'Reading',
  };

  static const Map<String, String> _fil = {
    'loading': 'Inihahanda ang detector…',
    'ready': 'Handa na. Itutok ang telepono sa harap.',
    'paused': 'Naka-pause',
    'resumed': 'Tuloy',
    'clear': 'Malinaw ang daan',
    'left': 'sa kaliwa',
    'right': 'sa kanan',
    'center': 'sa harap',
    'close': 'malapit',
    'veryClose': 'napakalapit',
    'object': 'Bagay',
    'sudden': 'Biglang malakas na tunog sa paligid',
    'continuous': 'Tuloy-tuloy na malakas na tunog. Maaaring alarma o sirena.',
    'gas': 'May tagas ng gas. Lumabas at buksan ang mga bintana.',
    'smoke': 'May usok. Tingnan kung may sunog.',
    'hot': 'Mainit. Huwag hawakan.',
    'noisy': 'Lumalakas ang ingay. Subukang huminga nang malalim.',
    'inhale': 'Huminga papasok',
    'hold': 'Pigilan',
    'exhale': 'Ilabas',
    'fall': 'May natumba',
    'sos': 'SOS',
    'snd_horn': 'May busina sa malapit',
    'snd_siren': 'May sirena sa malapit',
    'snd_alarm': 'May tumutunog na alarma',
    'snd_explosion': 'Malakas na putok sa malapit',
    'snd_scream': 'May sumisigaw',
    'snd_glass': 'May nabasag na salamin',
    'snd_baby': 'Umiiyak ang sanggol',
    'snd_doorbell': 'May nag-doorbell',
    'snd_knock': 'May kumakatok',
    'snd_dog': 'Tumatahol ang aso',
    'snd_phone': 'Tumutunog ang telepono',
    'snd_loud': 'Malakas na tunog sa paligid',
    'speaking': 'May nagsasalita',
    'sweep_clear': 'Walang harang',
    'read_none': 'Walang nakitang teksto. Ilapit ang telepono at subukan ulit.',
    'reading': 'Binabasa',
  };

  static String t(String key) =>
      (lang == Lang.fil ? _fil[key] : _en[key]) ?? _en[key] ?? key;

  static String get ttsLocale => lang == Lang.fil ? 'fil-PH' : 'en-US';
  static String get sttLocale => lang == Lang.fil ? 'fil_PH' : 'en_US';
}
