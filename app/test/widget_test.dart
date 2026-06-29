import 'package:flutter_test/flutter_test.dart';
import 'package:onesaver/models/media.dart';
import 'package:onesaver/utils/error_messages.dart';

void main() {
  group('validateInstagramInput', () {
    test('vazio pede um link', () {
      expect(validateInstagramInput('  '), contains('Cole um link'));
    });

    test('texto sem instagram.com é rejeitado', () {
      expect(
        validateInstagramInput('https://youtube.com/watch?v=x'),
        contains('não parece um link do Instagram'),
      );
    });

    test('instagram.com mas sem link de vídeo é rejeitado', () {
      expect(
        validateInstagramInput('https://instagram.com/algumperfil'),
        contains('não um link de vídeo'),
      );
    });

    test('reel válido passa (retorna null)', () {
      expect(
        validateInstagramInput('https://www.instagram.com/reel/ABC123_x/'),
        isNull,
      );
    });

    test('link com texto extra ao redor passa', () {
      expect(
        validateInstagramInput(
            'olha isso https://www.instagram.com/p/ABC123/ top'),
        isNull,
      );
    });
  });

  group('friendlyResolveError', () {
    test('invalid_url vira mensagem amigável', () {
      final msg = friendlyResolveError(
        const ResolveException('invalid_url', 'detalhe cru'),
      );
      expect(msg, contains('post, reel ou TV'));
    });

    test('auth_required explica conteúdo privado', () {
      final msg = friendlyResolveError(
        const ResolveException('auth_required', 'x'),
      );
      expect(msg, contains('privado'));
    });

    test('código desconhecido cai no message do backend', () {
      final msg = friendlyResolveError(
        const ResolveException('weird', 'mensagem específica'),
      );
      expect(msg, 'mensagem específica');
    });

    test('erro não-ResolveException tem fallback genérico', () {
      expect(friendlyResolveError(Exception('x')), contains('Algo deu errado'));
    });
  });
}
