# OneSaver — App (Flutter)

App cliente: cola/compartilha um link do Instagram → pré-visualiza → baixa na galeria.
Esta fase já roda em **modo STUB** (dados de exemplo, sem backend), com um mp4 real para
testar o download de ponta a ponta.

## Estrutura
```
lib/
  config.dart                 # flag useStub + apiBaseUrl
  models/media.dart           # ResolveResult / MediaItem (espelha o backend)
  services/
    resolve_service.dart      # interface + HttpResolveService (backend real)
    stub_resolve_service.dart # stub com dados falsos
    download_service.dart     # dio download + gal (salvar na galeria)
  state/providers.dart        # Riverpod
  screens/                    # home, preview, downloads
```

## Pré-requisitos
- Flutter SDK (canal stable). Verifique com `flutter doctor`.

## 1. Gerar as pastas de plataforma
Este repositório contém apenas `lib/` + `pubspec.yaml` (o código que importa).
Gere `android/`, `ios/` etc. **sem sobrescrever** o código existente:

```bash
cd app
flutter create --platforms=android,ios --org com.onesaver .
flutter pub get
```
(`flutter create` não sobrescreve arquivos já existentes em `lib/`.)

## 2. Rodar
```bash
# Modo STUB (padrão) — não precisa de backend:
flutter run

# Apontando para o backend real:
flutter run --dart-define=USE_STUB=false --dart-define=API_BASE_URL=http://10.0.2.2:8000
```
> Emulador Android acessa o host pela IP `10.0.2.2`. Em device físico, use o IP da
> sua máquina na rede local (ex.: `http://192.168.0.10:8000`).

## 3. Permissões necessárias (após `flutter create`)

O pacote `gal` (salvar na galeria) exige ajustes nos manifests gerados:

**`android/app/src/main/AndroidManifest.xml`** — dentro de `<manifest>`:
```xml
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

**`ios/Runner/Info.plist`**:
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Para salvar os vídeos baixados na sua galeria.</string>
```

## Compartilhamento (Compartilhar → OneSaver)
O app recebe links via folha de compartilhamento do Instagram (`receive_sharing_intent`).
O código Dart já está pronto; **falta a config de plataforma** — veja
[`SHARE_SETUP.md`](SHARE_SETUP.md) (intent-filter no Android; Share Extension no iOS).

## Estado atual / próximos passos
- [x] Fluxo: colar/detectar link → resolver (stub) → preview → baixar na galeria
- [x] Leitura de clipboard ao focar (com detecção de URL do Instagram)
- [x] **Fase 3:** share sheet (`receive_sharing_intent`) — código pronto; ver `SHARE_SETUP.md`
- [ ] Trocar `USE_STUB=false` quando o backend tiver cookies válidos
- [ ] Histórico persistente, configurações, ícone/splash
