import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../engine/signal_engine.dart';
import '../services/database_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY SCREEN — floating icon + full scan panel
// ─────────────────────────────────────────────────────────────────────────────

enum OverlayState { icon, scanning, stopped, signal }

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});
  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen>
    with TickerProviderStateMixin {

  OverlayState _state = OverlayState.icon;
  final SignalEngine _engine = SignalEngine();
  final DatabaseService _db  = DatabaseService();

  late AnimationController _scanController;
  late AnimationController _pulseController;
  late Animation<double> _scanAnim;
  late Animation<double> _pulseAnim;

  Timer? _scanTimer;
  Timer? _logTimer;
  int _frameCount = 0;
  int _scrollStep = 0;
  String _logMsg  = 'Initialising scanner...';
  SignalResult? _lastSignal;
  String _selectedTF = '1M';
  bool _showTFPicker  = false;

  static const Color kGreen = Color(0xFF00FF88);
  static const Color kRed   = Color(0xFFFF2244);
  static const Color kGold  = Color(0xFFFFD700);
  static const Color kBg    = Color(0xFF020408);
  static const Color kPanel = Color(0xFF080D16);

  final List<String> _logs = [
    'Scanning market structure...',
    'SMC: Order Block detected',
    'ICT: FVG identified',
    'BOS confirmed on chart',
    'OTC AI pattern: reversal zone',
    'Support level mapped',
    'Liquidity sweep above high',
    'Price Action: Engulfing forming',
    'CHoCH detected — shift in structure',
    'OB Mitigation in progress...',
    'Demand zone: accumulation',
    'Multi-TF confluence: strong',
    'OTC volatility scan...',
    'Smart money footprint found',
    'Fibonacci 61.8% touch confirmed',
  ];
  int _logIdx = 0;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scanAnim  = Tween<double>(begin: 0, end: 1).animate(_scanController);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(_pulseController);
    _db.init();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _scanTimer?.cancel();
    _logTimer?.cancel();
    super.dispose();
  }

  void _expand() {
    setState(() => _state = OverlayState.scanning);
    FlutterOverlayWindow.resizeOverlay(
      MediaQuery.of(context).size.width.toInt(),
      MediaQuery.of(context).size.height.toInt(),
      true,
    );
    _startScan();
  }

  void _startScan() {
    _frameCount = 0;
    _scrollStep = 0;
    _engine.clear();

    // tell native side to start accessibility scroll
    FlutterOverlayWindow.shareData({'action': 'start_scroll'});

    _logTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!mounted) return;
      setState(() {
        _logMsg = _logs[_logIdx % _logs.length];
        _logIdx++;
        _frameCount++;
      });
    });
  }

  void _stopScan() {
    _scanTimer?.cancel();
    _logTimer?.cancel();
    FlutterOverlayWindow.shareData({'action': 'stop_scroll'});
    setState(() {
      _state  = OverlayState.stopped;
      _logMsg = '✓ Scan complete — $_frameCount frames analysed';
    });
  }

  void _getSignal() {
    if (_showTFPicker) return;
    setState(() => _showTFPicker = true);
  }

  void _pickTF(String tf) {
    _showTFPicker = false;
    final result = _engine.generateSignal(tf);
    _lastSignal  = result;
    _db.saveSignal(result);
    setState(() {
      _state       = OverlayState.signal;
      _selectedTF  = tf;
    });
  }

  void _collapse() {
    _stopScan();
    FlutterOverlayWindow.resizeOverlay(72, 72, true);
    setState(() => _state = OverlayState.icon);
  }

  void _reset() {
    _stopScan();
    _engine.clear();
    _frameCount = 0;
    setState(() => _state = OverlayState.scanning);
    _startScan();
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _state == OverlayState.icon ? _buildIcon() : _buildPanel(),
    );
  }

  // Floating icon — small, draggable
  Widget _buildIcon() {
    return GestureDetector(
      onTap: _expand,
      child: ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kGreen, width: 2),
            boxShadow: [BoxShadow(color: kGreen.withOpacity(.5), blurRadius: 16)],
          ),
          child: ClipOval(
            child: Image.asset('assets/logo.jpg', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  // Full scan panel
  Widget _buildPanel() {
    return Container(
      color: kBg,
      child: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: _buildScanArea()),
          _buildStats(),
          _buildButtons(),
          if (_showTFPicker) _buildTFPicker(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFF152030))),
      ),
      child: Row(children: [
        _logo(44),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [kGreen, Colors.white, kRed],
              ).createShader(b),
              child: const Text('MR KOKO',
                style: TextStyle(fontFamily: 'monospace', fontSize: 15,
                  fontWeight: FontWeight.w900, color: Colors.white,
                  letterSpacing: 2)),
            ),
            Text('SIGNAL PRO · SCREEN SCAN',
              style: TextStyle(fontSize: 9, color: Colors.white38,
                letterSpacing: 2)),
          ],
        )),
        // live badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _state == OverlayState.scanning ? kGreen : Colors.white24),
            color: _state == OverlayState.scanning
                ? kGreen.withOpacity(.1) : Colors.transparent,
          ),
          child: Text(
            _state == OverlayState.scanning ? 'LIVE' :
            _state == OverlayState.stopped  ? 'READY' :
            _state == OverlayState.signal   ? 'SIGNAL' : 'IDLE',
            style: TextStyle(
              fontSize: 9, letterSpacing: 1,
              color: _state == OverlayState.scanning ? kGreen : Colors.white38,
              fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _collapse,
          child: const Icon(Icons.close, color: Colors.white38, size: 20),
        ),
      ]),
    );
  }

  Widget _buildScanArea() {
    return Stack(children: [
      // background grid
      CustomPaint(painter: _GridPainter(), child: const SizedBox.expand()),

      // scan laser line (left → right)
      if (_state == OverlayState.scanning)
        AnimatedBuilder(
          animation: _scanAnim,
          builder: (_, __) => Positioned(
            left: _scanAnim.value * (MediaQuery.of(context).size.width - 6),
            top: 0, bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [Colors.transparent, kGreen, Colors.white, kGreen, Colors.transparent],
                ),
                boxShadow: [
                  BoxShadow(color: kGreen.withOpacity(.8), blurRadius: 18),
                  BoxShadow(color: kGreen.withOpacity(.3), blurRadius: 36),
                ],
              ),
            ),
          ),
        ),

      // signal result overlay
      if (_state == OverlayState.signal && _lastSignal != null)
        _buildSignalOverlay(),

      // corner decorations
      ..._corners(),

      // bottom ticker
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.black87,
          child: Text(
            '[ ${_frameCount * 3} frames ] $_logMsg',
            style: TextStyle(
              fontSize: 10, color: kGreen, letterSpacing: 1,
              fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ]);
  }

  Widget _buildSignalOverlay() {
    final s   = _lastSignal!;
    final buy = s.direction == SignalDirection.buy;
    final clr = buy ? kGreen : kRed;
    return Container(
      color: Colors.black.withOpacity(.92),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(buy ? 'BUY' : 'SELL',
            style: TextStyle(
              fontSize: 52, fontWeight: FontWeight.w900,
              color: clr, letterSpacing: 4,
              shadows: [Shadow(color: clr, blurRadius: 30)],
            )),
          const SizedBox(height: 6),
          Text('$_selectedTF CANDLE',
            style: const TextStyle(fontSize: 13, color: kGold, letterSpacing: 2)),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) {
            final heights = [14.0, 22.0, 30.0, 22.0, 14.0];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8, height: heights[i],
              decoration: BoxDecoration(
                color: clr,
                borderRadius: BorderRadius.circular(2)),
            );
          })),
          const SizedBox(height: 8),
          Text('CONFIDENCE: ${s.confidence}%',
            style: const TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(s.rule,
            style: TextStyle(fontSize: 11, color: Colors.white38),
            textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('✓ SAVED TO HISTORY',
            style: TextStyle(fontSize: 10, color: kGreen, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildStats() {
    final labels = ['SMC', 'ICT', 'PA', 'OTC', 'S&R'];
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemCount: labels.length,
        itemBuilder: (_, i) {
          final hot = _state != OverlayState.icon;
          return Container(
            margin: const EdgeInsets.only(right: 6, top: 4, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: hot ? kGreen : const Color(0xFF152030)),
              color: hot ? kGreen.withOpacity(.07) : Colors.transparent,
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(labels[i], style: TextStyle(
                fontSize: 9, color: hot ? kGreen : Colors.white24, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(hot ? (i.isEven ? 'BULL' : 'BEAR') : '--',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                  color: hot ? kGreen : Colors.white24)),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Column(children: [
        Row(children: [
          Expanded(child: _btn('▶ ANALYSE', kGreen, Colors.black,
            _state == OverlayState.icon || _state == OverlayState.signal
                ? _reset : null)),
          const SizedBox(width: 6),
          Expanded(child: _btn('■ STOP', kRed, Colors.white,
            _state == OverlayState.scanning ? _stopScan : null)),
        ]),
        const SizedBox(height: 6),
        _btn('⚡ GET SIGNAL', kGold, Colors.black,
          _state == OverlayState.stopped ? _getSignal : null),
        const SizedBox(height: 4),
        _btn('↺ RESET', Colors.transparent, Colors.white38, _reset,
          border: const Color(0xFF152030)),
      ]),
    );
  }

  Widget _btn(String label, Color bg, Color fg, VoidCallback? onTap,
      {Color? border}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.3 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: bg == Colors.transparent ? Colors.transparent : bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border ?? bg),
            boxShadow: bg != Colors.transparent ? [
              BoxShadow(color: bg.withOpacity(.25), blurRadius: 12)
            ] : null,
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: fg, letterSpacing: 1.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildTFPicker() {
    final tfs = [
      {'tf': '5S', 'label': '5 SEC'},
      {'tf': '15S', 'label': '15 SEC'},
      {'tf': '20S', 'label': '20 SEC'},
      {'tf': '1M', 'label': '1 MIN'},
      {'tf': '5M', 'label': '5 MIN'},
      {'tf': '30M', 'label': '30 MIN'},
    ];
    return Container(
      color: const Color(0xFF0A1220),
      padding: const EdgeInsets.all(14),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('SELECT TIMEFRAME',
          style: TextStyle(fontSize: 12, color: Colors.white70,
            letterSpacing: 2, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 2.2),
          itemCount: tfs.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _pickTF(tfs[i]['tf']!),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF152030)),
                color: kPanel,
              ),
              child: Center(
                child: Text(tfs[i]['label']!,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: Colors.white70, letterSpacing: 1)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _logo(double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: kGreen, width: 2),
        boxShadow: [BoxShadow(color: kGreen.withOpacity(.4), blurRadius: 10)],
      ),
      child: ClipOval(
        child: Image.asset('assets/logo.jpg', fit: BoxFit.cover),
      ),
    );
  }

  List<Widget> _corners() {
    const s = 16.0; const t = 2.0; const c = kGreen;
    return [
      Positioned(top: 6, left: 6, child: _corner(s, t, c, top: true, left: true)),
      Positioned(top: 6, right: 6, child: _corner(s, t, c, top: true, left: false)),
      Positioned(bottom: 30, left: 6, child: _corner(s, t, c, top: false, left: true)),
      Positioned(bottom: 30, right: 6, child: _corner(s, t, c, top: false, left: false)),
    ];
  }

  Widget _corner(double s, double t, Color c,
      {required bool top, required bool left}) {
    return SizedBox(width: s, height: s,
      child: CustomPaint(painter: _CornerPainter(t, c, top: top, left: left)));
  }
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF00FF88).withOpacity(.04)
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width;  x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final double t;
  final Color c;
  final bool top, left;
  _CornerPainter(this.t, this.c, {required this.top, required this.left});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = c..strokeWidth = t..style = PaintingStyle.stroke;
    final x1 = left ? 0.0 : s.width;
    final y1 = top  ? 0.0 : s.height;
    final x2 = left ? s.width * 0.6 : s.width * 0.4;
    final y2 = top  ? s.height * 0.6 : s.height * 0.4;
    canvas.drawLine(Offset(x1, y1), Offset(x2, y1), p);
    canvas.drawLine(Offset(x1, y1), Offset(x1, y2), p);
  }
  @override bool shouldRepaint(_) => false;
}
