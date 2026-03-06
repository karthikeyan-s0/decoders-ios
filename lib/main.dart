import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const MaterialApp(
    home: DecodersController(),
    debugShowCheckedModeBanner: false,
  ));
}

class DecodersController extends StatefulWidget {
  const DecodersController({Key? key}) : super(key: key);

  @override
  State<DecodersController> createState() => _DecodersControllerState();
}

class _DecodersControllerState extends State<DecodersController> {
  // ── Network ────────────────────────────────────────────────────────────────
  Socket? _socket;
  bool _connected = false;
  String _serverIP = '';
  final String _xorKey = 'GET-N';
  final int _port = 54321;
  Timer? _heartbeatTimer;

  // ── Color Palette (Dark Green + Red) ──────────────────────────────────────
  static const Color bgColor = Color(0xFF0F2F1F);
  static const Color bg2 = Color(0xFF123B27);
  static const Color panel = Color(0xFF0A1F14);
  static const Color border = Color(0xFF144D30);
  static const Color border2 = Color(0xFF19633D);
  static const Color accent = Color(0xFF1ECB6B);
  static const Color accent2 = Color(0xFF25DE7A);
  static const Color dim = Color(0xFF17472F);
  static const Color txtHi = Color(0xFFE0F5EB);
  static const Color txtMed = Color(0xFF88CCAA);
  static const Color txtDim = Color(0xFF448866);
  static const Color redColor = Color(0xFFFF2B2B);
  static const Color greenSts = Color(0xFF1ECB6B);

  // ── UI State ────────────────────────────────────────────────────────────────
  final TextEditingController _ipController = TextEditingController();
  String _statusText = '● DISCONNECTED';
  Color _statusColor = redColor;
  String _adbStatus = 'ADB: --';
  Color _adbStatusColor = txtMed;

  // tab state
  int _currentTab = 0;

  // aim state
  String _activeAim = '';
  String _activeDragType = '';
  int _dragDelay = 100;

  // esp state
  bool _espEnabled = false;
  bool _hotkeysOn = true;

  // features
  Map<String, bool> _espFeatures = {
    'ESP_LINE': true,
    'ESP_BOX': true,
    'ESP_NAME': true,
    'ESP_DIST': true,
    'ESP_HEALTH': true,
  };

  // esp color state
  List<double> clrLine = [0.0, 0.4, 1.0, 1.0];
  List<double> clrBox = [0.0, 0.6, 1.0, 1.0];
  List<double> clrName = [0.8, 0.9, 1.0, 1.0];
  List<double> clrDist = [0.4, 0.55, 0.7, 1.0];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: bgColor,
      systemNavigationBarColor: bgColor,
    ));
  }

  @override
  void dispose() {
    _socket?.destroy();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  // ── XOR ───────────────────────────────────────────────────────────────────
  String xorCrypt(String data) {
    List<int> outBytes = [];
    for (int i = 0; i < data.length; i++) {
      outBytes.add(data.codeUnitAt(i) ^ _xorKey.codeUnitAt(i % _xorKey.length));
    }
    return String.fromCharCodes(outBytes);
  }

  // ── Networking ────────────────────────────────────────────────────────────
  void _doConnect() async {
    _serverIP = _ipController.text.trim();
    if (_serverIP.isEmpty) {
      _toast("Enter IP");
      return;
    }
    setState(() {
      _statusText = '● CONNECTING';
      _statusColor = accent;
    });

    try {
      _socket = await Socket.connect(_serverIP, _port, timeout: const Duration(seconds: 5));
      _socket!.listen(
        (List<int> event) {
          String response = utf8.decode(event);
          String dec = xorCrypt(response);
          if (dec.contains("OK")) {
             setState(() {
              _connected = true;
              _statusText = '● CONNECTED';
              _statusColor = greenSts;
             });
             _startHeartbeat();
             _toast("Connected");
          } else if (dec.contains("ADB_OK")) {
             setState(() {
               _adbStatus = 'ADB: OK';
               _adbStatusColor = greenSts;
             });
          }
        },
        onError: (e) => _doDisconnect(reason: 'Failed - check IP & firewall'),
        onDone: () => _doDisconnect(reason: 'Disconnected by server'),
      );

      _socket!.add(utf8.encode(xorCrypt("CONNECT")));
    } catch (e) {
      _doDisconnect(reason: 'Failed - check IP & firewall');
    }
  }

  void _doDisconnect({String? reason}) {
    if (reason != null) _toast(reason);
    _socket?.destroy();
    _heartbeatTimer?.cancel();
    setState(() {
      _connected = false;
      _statusText = '● DISCONNECTED';
      _statusColor = redColor;
      _adbStatus = 'ADB: --';
      _adbStatusColor = txtMed;
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_connected) _send("CONNECT");
    });
  }

  void _send(String command) {
    if (!_connected && command != "CONNECT" && command != "ESP_ENABLE:1") return;
    if (_socket != null) {
      try {
        _socket!.add(utf8.encode(xorCrypt(command)));
        if (command == "ADB_CONNECT") {
          setState(() {
            _adbStatus = 'ADB: CONNECTING...';
            _adbStatusColor = accent;
          });
        }
      } catch (e) {
        _doDisconnect();
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'monospace')),
      backgroundColor: dim,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build Helpers ──────────────────────────────────────────────────────────
  Widget _hRule(Color c) => Container(height: 1, color: c);

  Widget _flatBtn(String text, Color bg, Color fg, VoidCallback onTap, [bool expanded = false]) {
    Widget btn = GestureDetector(
       onTap: onTap,
       child: Container(
         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
         decoration: BoxDecoration(color: bg),
         child: Center(
           child: Text(text, style: TextStyle(
             color: fg, fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.bold
           )),
         ),
       )
    );
    return expanded ? Expanded(child: btn) : btn;
  }
  
  Widget _modeBtn(String label, String code, String currentGrp, ValueChanged<String> onChanged) {
    bool active = currentGrp == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(code),
        child: Container(
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? bg : panel,
            border: Border.all(color: active ? accent2 : border, width: 1.5)
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: active ? txtHi : txtMed, fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.bold
            )),
          ),
        ),
      )
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────
  Widget _buildAimTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 4),
          child: Text("AIMBOT MODE", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
        ),
        Row(
          children: [
            _modeBtn("RAGE", "AIM_RAGE", _activeAim, (v) { setState(() => _activeAim = v); _send(v); }),
            _modeBtn("COLLIDER", "AIM_COLLIDER", _activeAim, (v) { setState(() => _activeAim = v); _send(v); }),
            _modeBtn("DRAG", "AIM_DRAG", _activeAim, (v) { setState(() => _activeAim = v); _send(v); }),
          ],
        ),
        const SizedBox(height: 6),
        _flatBtn("DISABLE ALL", redColor, txtHi, () {
          setState(() => _activeAim = "AIM_OFF");
          _send("AIM_OFF");
        }),
        const SizedBox(height: 8),
        _hRule(border),
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4),
          child: Text("DRAG TYPE", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
        ),
        Row(
          children: [
            _flatBtn("MEDIUM", _activeDragType=="DRAG_MEDIUM"?accent:dim, _activeDragType=="DRAG_MEDIUM"?txtHi:txtHi, () { 
              setState(() => _activeDragType = "DRAG_MEDIUM"); _send("DRAG_MEDIUM"); 
            }, true),
            const SizedBox(width: 4),
            _flatBtn("LOW", _activeDragType=="DRAG_LOW"?accent:dim, _activeDragType=="DRAG_LOW"?txtHi:txtHi, () { 
              setState(() => _activeDragType = "DRAG_LOW"); _send("DRAG_LOW"); 
            }, true),
          ],
        ),
        const SizedBox(height: 8),
        _hRule(border),
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 4),
          child: Text("DRAG DELAY", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
        ),
        Row(
          children: [
             Expanded(
               child: SliderTheme(
                 data: SliderTheme.of(context).copyWith(
                   activeTrackColor: accent2,
                   inactiveTrackColor: dim,
                   thumbColor: accent2,
                   trackHeight: 2.0,
                 ),
                 child: Slider(
                   value: _dragDelay.toDouble(),
                   min: 0, max: 500,
                   onChanged: (v) {
                     setState(() => _dragDelay = v.toInt());
                   },
                   onChangeEnd: (v) {
                     _send("DRAG_DELAY:${v.toInt()}");
                   },
                 ),
               )
             ),
             SizedBox(
               width: 50,
               child: Text("${_dragDelay}ms", style: const TextStyle(color: accent2, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
             )
          ],
        )
      ],
    );
  }

  void _showColorPicker(String cmdPrefix, List<double> clr) {
    List<double> tempClr = List.from(clr);
    showDialog(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (c, setDlgState) {
        Color pClr = Color.fromRGBO((tempClr[0]*255).toInt(), (tempClr[1]*255).toInt(), (tempClr[2]*255).toInt(), tempClr[3]);
        return AlertDialog(
          backgroundColor: bg2,
          contentPadding: const EdgeInsets.all(16),
          title: const Text("Color", style: TextStyle(color: txtHi)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(height: 16, width: double.infinity, color: pClr, margin: const EdgeInsets.only(bottom: 16)),
               ...['R','G','B','A'].asMap().entries.map((e) => Row(
                 children: [
                   SizedBox(width: 16, child: Text(e.value, style: const TextStyle(color: txtMed, fontFamily: 'monospace', fontWeight: FontWeight.bold))),
                   Expanded(
                     child: SliderTheme(
                       data: SliderTheme.of(context).copyWith(
                         activeTrackColor: e.key == 0 ? Colors.red : e.key == 1 ? Colors.green : e.key == 2 ? Colors.blue : Colors.white,
                         thumbColor: e.key == 0 ? Colors.red : e.key == 1 ? Colors.green : e.key == 2 ? Colors.blue : Colors.white,
                       ),
                       child: Slider(
                         value: tempClr[e.key],
                         onChanged: (v) {
                           setDlgState((){ tempClr[e.key] = v; });
                         }
                       ),
                     )
                   )
                 ],
               ))
            ],
          ),
          actions: [
            TextButton(child: const Text("CANCEL", style: TextStyle(color: txtMed)), onPressed: ()=>Navigator.pop(ctx)),
            TextButton(child: const Text("APPLY", style: TextStyle(color: accent)), onPressed: (){
              setState(() {
                for (int i=0; i<4; i++) clr[i]=tempClr[i];
              });
              _send("$cmdPrefix:${clr[0].toStringAsFixed(3)},${clr[1].toStringAsFixed(3)},${clr[2].toStringAsFixed(3)},${clr[3].toStringAsFixed(3)}");
              Navigator.pop(ctx);
            }),
          ],
        );
      });
    });
  }

  Widget _buildEspTab() {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.stretch,
       children: [
         const Padding(
            padding: EdgeInsets.only(top: 10, bottom: 4),
            child: Text("ESP MASTER", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
         ),
         GestureDetector(
           onTap: () {
             setState(() => _espEnabled = !_espEnabled);
             _send("ESP_ENABLE:${_espEnabled ? '1':'0'}");
           },
           child: Container(
             padding: const EdgeInsets.symmetric(vertical: 12),
             decoration: BoxDecoration(
               color: _espEnabled ? bg : panel,
               border: Border.all(color: _espEnabled ? accent : border, width: 2)
             ),
             child: Center(
               child: Text("ESP: ${_espEnabled ? "ON" : "OFF"}", style: TextStyle(
                 color: _espEnabled ? txtHi : txtMed, fontFamily: 'monospace', fontWeight: FontWeight.bold
               )),
             ),
           )
         ),
         const SizedBox(height: 10),
         _hRule(border),
         const SizedBox(height: 6),
         const Text("FEATURES", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
         ...[
           {"lbl": "ESP Line", "cmd": "ESP_LINE", "clrCmd": "ESP_LINECOLOR", "clr": clrLine},
           {"lbl": "ESP Box", "cmd": "ESP_BOX", "clrCmd": "ESP_BOXCOLOR", "clr": clrBox},
           {"lbl": "ESP Name", "cmd": "ESP_NAME", "clrCmd": "ESP_NAMECOLOR", "clr": clrName},
           {"lbl": "ESP Distance", "cmd": "ESP_DIST", "clrCmd": "ESP_DISTCOLOR", "clr": clrDist},
           {"lbl": "ESP Health", "cmd": "ESP_HEALTH"},
         ].map((cfg) {
            String cmd = cfg["cmd"] as String;
            List<double>? clr = cfg["clr"] as List<double>?;
            Color? boxCol;
            if (clr != null) {
              boxCol = Color.fromRGBO((clr[0]*255).toInt(), (clr[1]*255).toInt(), (clr[2]*255).toInt(), clr[3]);
            }
            return Container(
               margin: const EdgeInsets.only(bottom: 2, top: 4),
               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
               decoration: BoxDecoration(color: panel, border: Border.all(color: border)),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Row(
                     children: [
                       Checkbox(
                          value: _espFeatures[cmd],
                          activeColor: accent2,
                          onChanged: (v) {
                             setState(() => _espFeatures[cmd] = v ?? false);
                             _send("$cmd:${(v ?? false) ? '1' : '0'}");
                          }
                       ),
                       Text(cfg["lbl"] as String, style: const TextStyle(color: txtHi, fontFamily: 'monospace', fontSize: 13)),
                     ],
                   ),
                   if (boxCol != null)
                     GestureDetector(
                       onTap: () => _showColorPicker(cfg["clrCmd"] as String, clr!),
                       child: Container(
                         width: 22, height: 22,
                         decoration: BoxDecoration(color: boxCol, border: Border.all(color: Colors.white24)),
                       )
                     )
                 ],
               ),
            );
         }).toList()
       ],
     );
  }

  Widget _buildSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
           padding: EdgeInsets.only(top: 10, bottom: 4),
           child: Text("CONNECTION", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
        ),
        _flatBtn("DISCONNECT", redColor, txtHi, () => _doDisconnect()),
        const SizedBox(height: 10),
        _hRule(border),
        const Padding(
           padding: EdgeInsets.only(top: 10, bottom: 4),
           child: Text("HOTKEYS", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
        ),
        GestureDetector(
           onTap: () {
             setState(() => _hotkeysOn = !_hotkeysOn);
             _send(_hotkeysOn ? "HOTKEY_ON" : "HOTKEY_OFF");
           },
           child: Container(
             padding: const EdgeInsets.symmetric(vertical: 12),
             decoration: BoxDecoration(
               color: _hotkeysOn ? bg : panel,
               border: Border.all(color: _hotkeysOn ? accent2 : border, width: 2)
             ),
             child: Center(
               child: Text("HOTKEYS  ${_hotkeysOn ? "ON" : "OFF"}", style: TextStyle(
                 color: _hotkeysOn ? txtHi : txtMed, fontFamily: 'monospace', fontWeight: FontWeight.bold
               )),
             ),
           )
         ),
         const SizedBox(height: 10),
         _hRule(border),
         const Padding(
           padding: EdgeInsets.only(top: 10, bottom: 4),
           child: Text("ADB", style: TextStyle(color: txtMed, fontSize: 10, fontFamily: 'monospace')),
        ),
        _flatBtn("CONNECT ADB", dim, txtHi, () {
           _send("ADB_CONNECT");
        }),
        const SizedBox(height: 30),
        const Center(
          child: Text("DECODERS v2.0  |  port 54321", style: TextStyle(color: txtDim, fontSize: 10, fontFamily: 'monospace'))
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
               // Header
               Row(
                 crossAxisAlignment: CrossAxisAlignment.center,
                 children: [
                   Container(
                     width: 3, height: 26, color: accent2, margin: const EdgeInsets.only(right: 10)
                   ),
                   const Text("DECODERS", style: TextStyle(color: redColor, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.25)),
                   const Text("  v2.0", style: TextStyle(color: redColor, fontSize: 12)),
                   const Spacer(),
                   const Text("CONTROLLER", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.3)),
                 ],
               ),
               const SizedBox(height: 10),
               _hRule(border2),
               const SizedBox(height: 8),

               // Connection Bar
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                 decoration: BoxDecoration(color: panel, border: Border.all(color: border)),
                 child: Row(
                   children: [
                     Expanded(
                       child: !_connected ? TextField(
                         controller: _ipController,
                         style: const TextStyle(color: txtHi, fontFamily: 'monospace', fontSize: 14),
                         decoration: const InputDecoration.collapsed(
                           hintText: "192.168.x.x",
                           hintStyle: TextStyle(color: txtDim, fontFamily: 'monospace')
                         ),
                       ) : const SizedBox()
                     ),
                     GestureDetector(
                       onTap: () {
                         if (_connected) _doDisconnect(); else _doConnect();
                       },
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                         color: _connected ? redColor : accent,
                         child: Text(_connected ? "DISCONNECT" : "CONNECT", style: const TextStyle(color: txtHi, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12)),
                       )
                     )
                   ],
                 ),
               ),
               const SizedBox(height: 6),

               // Status Row
               Row(
                 children: [
                   Text(_statusText, style: TextStyle(color: _statusColor, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.05)),
                   const Spacer(),
                   Text(_adbStatus, style: TextStyle(color: _adbStatusColor, fontFamily: 'monospace', fontSize: 12)),
                 ],
               ),
               const SizedBox(height: 4),
               _hRule(border),
               const SizedBox(height: 6),

               // Tab Bar
               Container(
                 decoration: BoxDecoration(color: panel, border: Border.all(color: border)),
                 child: Row(
                   children: ['AIM', 'ESP', 'SETTINGS'].asMap().entries.map((e) {
                     bool act = _currentTab == e.key;
                     return Expanded(
                       child: GestureDetector(
                         onTap: () => setState(() => _currentTab = e.key),
                         child: Container(
                           color: act ? accent : dim,
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           child: Center(
                             child: Text(e.value, style: TextStyle(color: act ? txtHi : txtMed, fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.15)),
                           )
                         )
                       )
                     );
                   }).toList()
                 ),
               ),
               const SizedBox(height: 4),
               _hRule(border),

               // Tab Contents
               if (_currentTab == 0) _buildAimTab(),
               if (_currentTab == 1) _buildEspTab(),
               if (_currentTab == 2) _buildSettingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}
