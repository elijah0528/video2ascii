import 'dart:math';

/// Represents a single ripple effect from a tap
class Ripple {
  final double x;
  final double y;
  final double startTime;
  double radius = 0;
  double opacity = 1.0;

  Ripple({
    required this.x,
    required this.y,
    required this.startTime,
  });

  /// Update ripple state based on elapsed time
  /// Returns false if ripple should be removed
  bool update(double currentTime, double speed) {
    final elapsed = currentTime - startTime;
    radius = elapsed * speed * 100;
    opacity = max(0, 1.0 - elapsed * 0.5);
    return opacity > 0;
  }

  /// Check if a point is within the ripple ring
  double getIntensity(double px, double py, double ringWidth) {
    final distance = sqrt(pow(px - x, 2) + pow(py - y, 2));
    final innerRadius = radius - ringWidth;
    final outerRadius = radius + ringWidth;

    if (distance >= innerRadius && distance <= outerRadius) {
      // Smooth falloff at ring edges
      final distFromCenter = (distance - radius).abs();
      return opacity * (1.0 - distFromCenter / ringWidth);
    }
    return 0;
  }
}

/// Manages multiple concurrent ripple effects
class RippleManager {
  final List<Ripple> _ripples = [];
  static const int maxRipples = 8;
  double _speed = 1.0;

  double get speed => _speed;
  set speed(double value) => _speed = value.clamp(0.5, 3.0);

  List<Ripple> get ripples => List.unmodifiable(_ripples);

  /// Add a new ripple at normalized coordinates (0-1)
  void addRipple(double x, double y, double currentTime) {
    if (_ripples.length >= maxRipples) {
      _ripples.removeAt(0);
    }
    _ripples.add(Ripple(x: x, y: y, startTime: currentTime));
  }

  /// Update all ripples and remove expired ones
  void update(double currentTime) {
    _ripples.removeWhere((ripple) => !ripple.update(currentTime, _speed));
  }

  /// Get combined ripple intensity at a point
  double getIntensityAt(double x, double y, {double ringWidth = 0.05}) {
    double intensity = 0;
    for (final ripple in _ripples) {
      intensity += ripple.getIntensity(x, y, ringWidth);
    }
    return intensity.clamp(0.0, 1.0);
  }

  void clear() {
    _ripples.clear();
  }
}
