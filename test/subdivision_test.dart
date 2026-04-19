import 'package:flutter_test/flutter_test.dart';
import 'package:precise_metronome/precise_metronome.dart';

void main() {
  test('pulsesPerBeat matches the expected musical subdivision', () {
    expect(Subdivision.none.pulsesPerBeat, 1);
    expect(Subdivision.duple.pulsesPerBeat, 2);
    expect(Subdivision.triplet.pulsesPerBeat, 3);
    expect(Subdivision.quadruple.pulsesPerBeat, 4);
  });

  test('all subdivisions are strictly increasing in pulses per beat', () {
    const values = Subdivision.values;
    for (var i = 1; i < values.length; i++) {
      expect(
        values[i].pulsesPerBeat,
        greaterThan(values[i - 1].pulsesPerBeat),
      );
    }
  });
}
