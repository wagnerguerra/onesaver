import 'package:dio/dio.dart';

import '../models/media.dart';

/// Contrato de resolução: recebe uma URL do Instagram e devolve as mídias.
/// Implementado por [StubResolveService] (fake) e [HttpResolveService] (backend).
abstract interface class ResolveService {
  Future<ResolveResult> resolve(String url);
}

/// Implementação real: chama `POST /resolve` no backend OneSaver.
class HttpResolveService implements ResolveService {
  HttpResolveService(this._dio);
  final Dio _dio;

  @override
  Future<ResolveResult> resolve(String url) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/resolve',
        data: {'url': url},
      );
      return ResolveResult.fromJson(res.data!);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        throw ResolveException(
          data['error'] as String,
          (data['detail'] as String?) ?? 'Não foi possível resolver o link.',
        );
      }
      throw ResolveException(
        'network',
        e.message ?? 'Falha de rede ao falar com o servidor.',
      );
    }
  }
}
