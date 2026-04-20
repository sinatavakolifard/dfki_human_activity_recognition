import 'dart:async';
import 'dart:io';

import 'package:sensors_plus/sensors_plus.dart';

import '../models/sensor_sample.dart';

/// Streams accelerometer, gyroscope, and magnetometer data and emits
/// time-aligned [SensorSample]s at a fixed target frequency.
///
/// The OS-reported rate per sensor is only a hint, and each sensor may tick
/// at slightly different times. We keep the most recent reading from each
/// stream and emit a row on a fixed periodic timer (default 34 Hz).
class SensorService {
  SensorService({this.targetHz = 34});

  final int targetHz;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<MagnetometerEvent>? _magSub;
  Timer? _sampleTimer;

  double _ax = 0, _ay = 0, _az = 0;
  double _gx = 0, _gy = 0, _gz = 0;
  double _mx = 0, _my = 0, _mz = 0;
  bool _haveAccel = false;
  bool _haveGyro = false;
  bool _haveMag = false;

  final StreamController<SensorSample> _controller =
      StreamController<SensorSample>.broadcast();

  Stream<SensorSample> get samples => _controller.stream;

  bool get isRunning => _sampleTimer?.isActive ?? false;

  Duration get _samplingPeriod =>
      Duration(microseconds: (1000000 / targetHz).round());

  Future<void> start() async {
    if (isRunning) return;

    // Ask each stream for a period slightly faster than our target so that we
    // usually have a fresh value to emit on each timer tick.
    final period = Duration(
      microseconds: (_samplingPeriod.inMicroseconds * 0.8).round(),
    );

    _accelSub = accelerometerEventStream(samplingPeriod: period).listen(
      (e) {
        _ax = e.x;
        _ay = e.y;
        _az = e.z;
        _haveAccel = true;
      },
      onError: (_) {},
      cancelOnError: false,
    );
    _gyroSub = gyroscopeEventStream(samplingPeriod: period).listen(
      (e) {
        _gx = e.x;
        _gy = e.y;
        _gz = e.z;
        _haveGyro = true;
      },
      onError: (_) {},
      cancelOnError: false,
    );
    _magSub = magnetometerEventStream(samplingPeriod: period).listen(
      (e) {
        _mx = e.x;
        _my = e.y;
        _mz = e.z;
        _haveMag = true;
      },
      onError: (_) {},
      cancelOnError: false,
    );

    _sampleTimer = Timer.periodic(_samplingPeriod, (_) {
      if (!_haveAccel || !_haveGyro || !_haveMag) {
        return; // wait until all three streams have produced a first value
      }
      final sample = SensorSample(
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        accelX: _ax,
        accelY: _ay,
        accelZ: _az,
        gyroX: _gx,
        gyroY: _gy,
        gyroZ: _gz,
        magX: _mx,
        magY: _my,
        magZ: _mz,
      );
      _controller.add(sample);
    });
  }

  Future<void> stop() async {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    await _accelSub?.cancel();
    await _gyroSub?.cancel();
    await _magSub?.cancel();
    _accelSub = null;
    _gyroSub = null;
    _magSub = null;
    _haveAccel = _haveGyro = _haveMag = false;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}

/// Buffered CSV writer for a single recording session.
///
/// Batches rows in memory and flushes to disk periodically to avoid a
/// filesystem write on every sample.
class SessionWriter {
  SessionWriter(this.file, {this.flushEvery = 256});

  final File file;
  final int flushEvery;

  final List<String> _buffer = [];
  IOSink? _sink;
  int _written = 0;

  Future<void> open() async {
    _sink = file.openWrite(mode: FileMode.writeOnly);
    _sink!.writeln(SensorSample.csvHeader.join(','));
  }

  int get sampleCount => _written;

  void add(SensorSample s) {
    _buffer.add(s.toCsvRow());
    _written++;
    if (_buffer.length >= flushEvery) {
      _flushBuffer();
    }
  }

  void _flushBuffer() {
    if (_buffer.isEmpty || _sink == null) return;
    _sink!.writeln(_buffer.join('\n'));
    _buffer.clear();
  }

  Future<void> close() async {
    _flushBuffer();
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
