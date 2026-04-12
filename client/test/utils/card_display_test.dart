import 'package:flutter_test/flutter_test.dart';
import 'package:ohhell_client/src/utils/card_display.dart';

void main() {
  group('suitSymbol', () {
    test('returns spade symbol for spades', () {
      expect(suitSymbol('spades'), '\u2660');
    });

    test('returns heart symbol for hearts', () {
      expect(suitSymbol('hearts'), '\u2665');
    });

    test('returns diamond symbol for diamonds', () {
      expect(suitSymbol('diamonds'), '\u2666');
    });

    test('returns club symbol for clubs', () {
      expect(suitSymbol('clubs'), '\u2663');
    });

    test('returns ? for unknown suit', () {
      expect(suitSymbol('unknown'), '?');
    });
  });

  group('rankDisplay', () {
    test('returns A for ace', () {
      expect(rankDisplay('ace'), 'A');
    });

    test('returns K for king', () {
      expect(rankDisplay('king'), 'K');
    });

    test('returns Q for queen', () {
      expect(rankDisplay('queen'), 'Q');
    });

    test('returns J for jack', () {
      expect(rankDisplay('jack'), 'J');
    });

    test('returns 10 for ten', () {
      expect(rankDisplay('ten'), '10');
    });

    test('returns 2 for two', () {
      expect(rankDisplay('two'), '2');
    });

    test('returns 3 for three', () {
      expect(rankDisplay('three'), '3');
    });

    test('returns 4 for four', () {
      expect(rankDisplay('four'), '4');
    });

    test('returns 5 for five', () {
      expect(rankDisplay('five'), '5');
    });

    test('returns 6 for six', () {
      expect(rankDisplay('six'), '6');
    });

    test('returns 7 for seven', () {
      expect(rankDisplay('seven'), '7');
    });

    test('returns 8 for eight', () {
      expect(rankDisplay('eight'), '8');
    });

    test('returns 9 for nine', () {
      expect(rankDisplay('nine'), '9');
    });

    test('returns raw name for unknown rank', () {
      expect(rankDisplay('joker'), 'joker');
    });
  });
}
