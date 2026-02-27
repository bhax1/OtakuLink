import 'package:flutter/material.dart';

class WebtoonScrollPhysics extends ClampingScrollPhysics {
  const WebtoonScrollPhysics({super.parent});

  @override
  WebtoonScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return WebtoonScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);

    if (position.outOfRange) {
      double? end;
      if (position.pixels > position.maxScrollExtent)
        end = position.maxScrollExtent;
      if (position.pixels < position.minScrollExtent)
        end = position.minScrollExtent;

      if (end != null) {
        return ScrollSpringSimulation(
          spring,
          position.pixels,
          end,
          velocity,
          tolerance: tolerance,
        );
      }
    }

    if (velocity.abs() < tolerance.velocity) return null;

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: 0.008,
      tolerance: tolerance,
    );
  }
}
