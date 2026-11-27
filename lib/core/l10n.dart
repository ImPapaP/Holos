import 'strings.dart';

/// Screen text in English or Tagalog. Write the English text; Tagalog comes from [_tl].
String L(String en) => S.lang == Lang.fil ? (_tl[en] ?? en) : en;

const Map<String, String> _tl = {
  // Home, onboarding, profiles
  'One app for every sense. Choose the profile that fits you. You can change it later in Settings.':
      'Isang app para sa bawat pandama. Piliin ang profile na bagay sa iyo. Mapapalitan mo ito sa Settings.',
  'Recommended for you': 'Para sa iyo',
  'Other modules': 'Iba pang module',
  'Add a caregiver number in Settings so SOS can reach them.': 'Maglagay ng numero ng tagapag-alaga sa Settings para maabot sila ng SOS.',
  'Voice command': 'Utos gamit ang boses',
  'Settings': 'Settings',
  'Profile': 'Profile',
  'Blind or low vision': 'Bulag o malabo ang paningin',
  'Deaf or hard of hearing': 'Bingi o mahina ang pandinig',
  'Deafblind': 'Bingi at bulag',
  'Sensory sensitive': 'Sensitibo sa paligid',
  'Lost smell or touch': 'Nawalan ng pang-amoy o pandama',
  'Voice + vibration': 'Boses + vibration',
  'Screen alerts + vibration': 'Alerto sa screen + vibration',
  'Vibration only': 'Vibration lang',
  'Autism, ADHD, anxiety: gentle alerts + vibration': 'Autism, ADHD, anxiety: banayad na alerto + vibration',
  'Voice + screen alerts + vibration': 'Boses + alerto sa screen + vibration',

  // Module names and descriptions
  'Walk with obstacle alerts by vibration': 'Maglakad na may babala sa harang gamit ang vibration',
  'Point the phone to scan around you': 'Itutok ang telepono para suriin ang paligid',
  'Slide a finger to feel where things are': 'Idaan ang daliri para maramdaman kung nasaan ang mga bagay',
  'Read signs, labels and documents aloud': 'Basahin nang malakas ang karatula, label at dokumento',
  'Describe the scene in sentences (online)': 'Ilarawan ang paligid sa mga pangungusap (online)',
  'Say colors and how bright it is': 'Sabihin ang kulay at kung gaano kaliwanag',
  'Identify peso bills by sound and vibration': 'Kilalanin ang perang papel gamit ang tunog at vibration',
  'Vibration guidance to a saved place': 'Gabay sa vibration papunta sa naka-save na lugar',
  'Sound alerts and live captions': 'Alerto sa tunog at live caption',
  'Messages delivered as vibration': 'Mensaheng ipinadadala bilang vibration',
  'Noise monitor and haptic breathing': 'Bantay-ingay at gabay sa paghinga',
  'Gas, smoke and heat warnings': 'Babala sa gas, usok at init',
  'Emergency alert to your caregiver': 'Emergency na alerto sa tagapag-alaga',
  'Sensor Alerts': 'Alerto ng Sensor',
  'Touch Talk': 'Usap sa Pandama',

  // Settings
  'Caregiver (for SOS)': 'Tagapag-alaga (para sa SOS)',
  'Caregiver name': 'Pangalan ng tagapag-alaga',
  'Caregiver mobile number': 'Mobile number ng tagapag-alaga',
  'Save caregiver': 'I-save ang tagapag-alaga',
  'Caregiver saved': 'Na-save ang tagapag-alaga',
  'Safety': 'Kaligtasan',
  'Fall detection': 'Pag-detect ng pagkahulog',
  'Starts SOS if the phone detects a hard fall while Gabay is open': 'Magsisimula ang SOS kapag may malakas na pagbagsak habang bukas ang Gabay',
  'Appearance': 'Itsura',
  'Each theme serves a need. Alerts always use color plus an icon, text and vibration.':
      'Bawat tema ay may layunin. Laging may kulay, icon, teksto at vibration ang mga alerto.',
  'Auto': 'Awtomatiko',
  'Uses the light sensor when Gabay opens: Daylight outdoors, Gabay Night indoors':
      'Ginagamit ang light sensor pagbukas ng Gabay: Daylight sa labas, Gabay Night sa loob',
  'Gabay Night': 'Gabay Gabi',
  'High Contrast': 'Mataas na Kontrast',
  'Daylight': 'Liwanag ng Araw',
  'Colorblind-safe': 'Para sa Color Blind',
  'Calm': 'Kalmado',
  'Yellow on black for visibility. Saves battery on long walks.': 'Dilaw sa itim para madaling makita. Tipid sa baterya sa mahabang lakad.',
  'Strongest contrast, no gray text. For low vision.': 'Pinakamalakas na kontrast, walang abong teksto. Para sa malabo ang paningin.',
  'Readable in direct sunlight outdoors.': 'Nababasa kahit tirik ang araw sa labas.',
  'Blue and orange instead of red and green.': 'Asul at kahel sa halip na pula at berde.',
  'Soft colors, no flashing. For sensory-sensitive users.': 'Malalambot na kulay, walang kislap. Para sa sensitibo sa paligid.',
  'Learn': 'Matuto',
  'Practice vibration patterns': 'Sanayin ang mga vibration',
  'Feel what each alert means': 'Damhin ang ibig sabihin ng bawat alerto',
  'AI engines': 'Mga AI engine',
  'Speed boost': 'Pabilisin',
  'Offline captions and voice commands': 'Offline na caption at utos sa boses',
  'Uses on-device speech recognition when the phone supports it (Android 13+, language pack installed).':
      'Gumagamit ng speech recognition sa telepono kung kaya nito (Android 13+, may language pack).',
  'Scene description (Ilarawan)': 'Paglalarawan ng paligid (Ilarawan)',
  'Needs a free Google Gemini API key from aistudio.google.com. Photos you describe are sent to Google.':
      'Kailangan ng libreng Google Gemini API key mula sa aistudio.google.com. Ipinapadala sa Google ang mga larawang inilalarawan.',
  'Gemini API key': 'Gemini API key',
  'Model name': 'Pangalan ng model',
  'Save key': 'I-save ang key',
  'Scene description settings saved': 'Na-save ang settings ng paglalarawan',
  'Testing mode (for evaluation)': 'Testing mode (para sa ebalwasyon)',
  'Testing mode': 'Testing mode',
  'Logs every alert with time and confidence, and shows Correct / Wrong buttons for the tester.':
      'Itinatala ang bawat alerto kasama ang oras at kumpiyansa, at may Tama / Mali na button para sa tester.',
  'Export log': 'I-export ang log',
  'Clear': 'Burahin',
  'Change profile': 'Palitan ang profile',
  'Language': 'Wika',

  // Practice
  'Practice': 'Pagsasanay',
  'Tap a pattern to feel it. In Sight, faster repeats mean the object is closer.':
      'Pindutin ang pattern para maramdaman. Sa Lakad, mas mabilis na ulit ay mas malapit ang bagay.',
  'Object straight ahead': 'May bagay sa harap',
  'One long buzz': 'Isang mahabang buzz',
  'Object on your left': 'May bagay sa kaliwa mo',
  'Two short buzzes': 'Dalawang maikling buzz',
  'Object on your right': 'May bagay sa kanan mo',
  'Three short buzzes': 'Tatlong maikling buzz',
  'Vehicle close: stop': 'Malapit na sasakyan: huminto',
  'Rapid burst, then direction': 'Mabilis na sunod-sunod, saka direksyon',
  'Sudden loud sound': 'Biglang malakas na tunog',
  'Three long buzzes': 'Tatlong mahabang buzz',
  'Continuous loud sound (alarm, siren)': 'Tuloy-tuloy na malakas na tunog (alarma, sirena)',
  'Five medium buzzes': 'Limang katamtamang buzz',
  'Gas or smoke': 'Gas o usok',
  'Three very long buzzes': 'Tatlong napakahabang buzz',
  'Hot surface': 'Mainit na bagay',
  'Four quick buzzes': 'Apat na mabilis na buzz',
  'Emergency mode on': 'Naka-on ang emergency mode',
  'S-O-S rhythm': 'Ritmo ng S-O-S',
  'Gabay is open': 'Bukas na ang Gabay',
  'Four quick pulses: braille "g"': 'Apat na mabilis na pulso: braille na "g"',

  // Common buttons
  'Exit': 'Lumabas',
  'Stop': 'Ihinto',
  'Save': 'I-save',
  'Cancel': 'Kanselahin',
  'Read again': 'Basahin ulit',
  'Correct': 'Tama',
  'Wrong': 'Mali',
  'Boxes on': 'May kahon',
  'Boxes off': 'Walang kahon',
  'Live view': 'Live',
  'Hold scene': 'I-hold ang eksena',
  'Tap: pause · Double-tap: repeat · Hold: SOS': 'Pindot: pause · Dalawang pindot: ulitin · Pindutin nang matagal: SOS',
  'Lakad is running. Tap to pause, double tap to repeat, hold for SOS.':
      'Tumatakbo ang Lakad. Pindutin para mag-pause, dalawang beses para ulitin, matagal para sa SOS.',

  // Sound / captions
  'Start sound alerts': 'Simulan ang alerto sa tunog',
  'Stop sound alerts': 'Ihinto ang alerto sa tunog',
  'Recognizes horns, sirens, alarms, doorbells, knocking, babies crying, dogs and more.':
      'Nakikilala ang busina, sirena, alarma, doorbell, katok, iyak ng sanggol, aso at iba pa.',
  'Alerts you to loud sounds by vibration and screen flashes.': 'Inaalerto ka sa malalakas na tunog gamit ang vibration at kislap ng screen.',
  'Sound level': 'Lakas ng tunog',
  'Sensitivity': 'Sensitibidad',
  'Live captions': 'Live caption',
  'Start live captions': 'Simulan ang live caption',
  'Stop live captions': 'Ihinto ang live caption',
  'Recent sounds': 'Mga huling tunog',
  'No sounds yet': 'Wala pang tunog',
  'Microphone permission denied': 'Hindi pinayagan ang mikropono',
  'Speech recognition is not available on this phone': 'Walang speech recognition sa teleponong ito',

  // Touch Talk
  'Type a message and the phone vibrates it in Morse code, one letter at a time.':
      'Mag-type ng mensahe at ivi-vibrate ito ng telepono sa Morse code, isa-isang letra.',
  'Type a message': 'Mag-type ng mensahe',
  'Send as vibration': 'Ipadala bilang vibration',
  'Slow': 'Mabagal',
  'Normal': 'Katamtaman',
  'Fast': 'Mabilis',
  'Quick messages': 'Mabilisang mensahe',
  'Tap Reply (for the deafblind user)': 'Sagot sa Pindot (para sa bingi at bulag)',
  'Tap for a dot, hold for a dash. Pause to finish a letter. Your family reads or hears the reply.':
      'Pindot para sa tuldok, matagal para sa guhit. Huminto para tapusin ang letra. Mababasa o maririnig ng pamilya ang sagot.',
  'Morse tap pad. Tap for dot, hold for dash.': 'Pad ng Morse. Pindot para sa tuldok, matagal para sa guhit.',
  'Reply appears here': 'Dito lalabas ang sagot',
  'Speak reply': 'Sabihin ang sagot',

  // Calm
  'Watches the noise around you and warns before it gets overwhelming. Follow the breathing buzz to settle down.':
      'Binabantayan ang ingay sa paligid at nagbababala bago ito maging sobra. Sundan ang buzz ng paghinga para kumalma.',
  'Start noise monitor': 'Simulan ang bantay-ingay',
  'Stop noise monitor': 'Ihinto ang bantay-ingay',
  'Noise level (estimate)': 'Lakas ng ingay (tantiya)',
  'Ready': 'Handa',
  'Start breathing guide': 'Simulan ang gabay sa paghinga',
  'Stop breathing guide': 'Ihinto ang gabay sa paghinga',
  'Breathe in with the quick buzzes, out with the slow ones.': 'Huminga papasok sa mabilis na buzz, palabas sa mabagal.',
  'Busy': 'Maingay',
  'Loud': 'Napakaingay',

  // Sensor
  'For people who cannot smell gas or smoke, or cannot feel heat. Connect the Gabay ESP32 sensor (MQ-2 gas/smoke + temperature) by Bluetooth.':
      'Para sa hindi nakakaamoy ng gas o usok, o hindi nakakaramdam ng init. Ikonekta ang Gabay ESP32 sensor (MQ-2 gas/usok + temperatura) sa Bluetooth.',
  'Connect sensor': 'Ikonekta ang sensor',
  'Disconnect sensor': 'Idiskonekta ang sensor',
  'Not connected': 'Hindi nakakonekta',
  'Gas / smoke': 'Gas / usok',
  'Temperature': 'Temperatura',
  'Test alerts (no sensor needed)': 'Subukan ang alerto (walang sensor)',
  'Test: Gas leak': 'Subok: Tagas ng gas',
  'LPG detected in the kitchen': 'May LPG sa kusina',
  'Test: Smoke': 'Subok: Usok',
  'Smoke or burning food': 'Usok o nasusunog na pagkain',
  'Test: Hot surface': 'Subok: Mainit na bagay',
  'Water or pan above safe temperature': 'Tubig o kawaling sobrang init',

  // SOS
  'Text caregiver now': 'I-text ang tagapag-alaga',
  'Call caregiver': 'Tawagan ang tagapag-alaga',
  "Cancel, I'm OK": 'Kanselahin, OK lang ako',
  'Or hold anywhere for 1.5 seconds to cancel': 'O pindutin nang matagal (1.5 segundo) para kanselahin',
  'Manual SOS': 'Manwal na SOS',
  'Fall detected': 'May natumba',
  'Location permission denied': 'Hindi pinayagan ang lokasyon',
  'Location ready': 'Handa na ang lokasyon',
  'Could not get location': 'Hindi makuha ang lokasyon',
  'No caregiver number. Add one in Settings.': 'Walang numero ng tagapag-alaga. Maglagay sa Settings.',
  'Could not open SMS app': 'Hindi mabuksan ang SMS app',
  'Tap to close': 'Pindutin para isara',

  // Navigation
  'Guides you toward a saved place using vibration. It points in a straight line, so follow sidewalks and use your cane.':
      'Ginagabayan ka papunta sa naka-save na lugar gamit ang vibration. Tuwid na direksyon ito, kaya sumunod sa bangketa at gamitin ang tungkod.',
  'Stop guiding': 'Ihinto ang paggabay',
  'Saved places': 'Mga naka-save na lugar',
  'No saved places yet.': 'Wala pang naka-save na lugar.',
  'Tap to be guided here': 'Pindutin para magabayan dito',
  'Save this place': 'I-save ang lugar na ito',
  'Delete all saved places': 'Burahin lahat ng naka-save na lugar',
  'Name this place': 'Pangalanan ang lugar',
  'Home, school, terminal': 'Bahay, paaralan, terminal',

  // Scene / peso / camera
  'Needs internet. The photo is sent to Google to be described.': 'Kailangan ng internet. Ipinapadala ang larawan sa Google para ilarawan.',
  'Add a Gemini API key in Settings → Scene description to use this module.':
      'Maglagay ng Gemini API key sa Settings → Paglalarawan ng paligid para magamit ito.',
  'Could not describe the scene. Check your internet connection.': 'Hindi mailarawan ang paligid. Tingnan ang internet.',
  'Peso model not installed yet': 'Wala pang naka-install na peso model',
  'Train it with the notebook in the training/ folder of the GitHub repo: take about 100 photos of each bill (front and back, different lighting), train on Google Colab, then add peso.tflite and peso_labels.txt to assets/. The next build includes it automatically.':
      'I-train ito gamit ang notebook sa training/ folder ng GitHub repo: kumuha ng mga 100 larawan ng bawat perang papel (harap at likod, iba-ibang liwanag), i-train sa Google Colab, saka idagdag ang peso.tflite at peso_labels.txt sa assets/. Kasama na ito sa susunod na build.',
  '20 = 1 buzz · 50 = 2 · 100 = 3 · 200 = 4 · 500 = 5 · 1000 = 6': '20 = 1 buzz · 50 = 2 · 100 = 3 · 200 = 4 · 500 = 5 · 1000 = 6',
  'Camera permission denied': 'Hindi pinayagan ang camera',
};
