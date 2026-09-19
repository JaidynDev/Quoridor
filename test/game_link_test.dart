import 'package:flutter_test/flutter_test.dart';
import 'package:workspace/services/game_link.dart';

void main() {
  test('points at the deployed site with the match route in the hash', () {
    expect(
      buildGameLink('abc123', pageUrl: Uri.parse('https://quoridor.web.app/')),
      'https://quoridor.web.app/#/game/abc123',
    );
  });

  test('treats index.html as the folder it sits in', () {
    expect(
      buildGameLink(
        'abc123',
        pageUrl: Uri.parse('https://quoridor.web.app/index.html'),
      ),
      'https://quoridor.web.app/#/game/abc123',
    );
  });

  test('keeps the existing route out of the link', () {
    expect(
      buildGameLink(
        'xyz',
        pageUrl: Uri.parse('https://quoridor.web.app/#/game/other'),
      ),
      'https://quoridor.web.app/#/game/xyz',
    );
  });

  test('keeps a sub-path host like GitHub Pages', () {
    expect(
      buildGameLink(
        'abc123',
        pageUrl: Uri.parse('https://jaidyndev.github.io/Quoridor/'),
      ),
      'https://jaidyndev.github.io/Quoridor/#/game/abc123',
    );
    expect(
      buildGameLink(
        'abc123',
        pageUrl: Uri.parse('https://jaidyndev.github.io/Quoridor/index.html'),
      ),
      'https://jaidyndev.github.io/Quoridor/#/game/abc123',
    );
  });

  test('keeps a local server pointing at itself', () {
    expect(
      buildGameLink('abc123', pageUrl: Uri.parse('http://localhost:8000/')),
      'http://localhost:8000/#/game/abc123',
    );
  });

  test('falls back to the deployed site off the web', () {
    expect(
      buildGameLink('abc123', pageUrl: Uri.parse('file:///app/index.html')),
      '$kAppHomeUrl/#/game/abc123',
    );
  });
}
