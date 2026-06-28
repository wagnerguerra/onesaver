# Configuração do "Compartilhar → OneSaver" (receive_sharing_intent)

O código Dart já está pronto (`HomeScreen` escuta os compartilhamentos). Falta
configurar **as plataformas** — isso precisa ser feito **depois** de rodar
`flutter create` (que gera `android/` e `ios/`). Sem estes passos, o app não
aparece na folha de compartilhamento do Instagram.

---

## Android (obrigatório, MVP)

Edite `android/app/src/main/AndroidManifest.xml`.

1. Na tag `<activity android:name=".MainActivity" ...>`, garanta o launch mode:
```xml
<activity
    android:name=".MainActivity"
    android:launchMode="singleTask"
    android:theme="@style/LaunchTheme"
    ... >
```

2. **Dentro** dessa mesma `<activity>`, adicione o intent-filter de texto
   (o Instagram compartilha o link como `text/plain`):
```xml
    <intent-filter>
        <action android:name="android.intent.action.SEND" />
        <category android:name="android.intent.category.DEFAULT" />
        <data android:mimeType="text/plain" />
    </intent-filter>
```

Pronto. Após `flutter run`, abra o Instagram → um reel → **Compartilhar →
OneSaver**. O app abre, resolve o link e vai direto para a pré-visualização.

> `launchMode="singleTask"` é importante: garante que o app já aberto receba o
> compartilhamento pelo *stream* em vez de criar uma nova instância.

---

## iOS (Fase posterior — exige Share Extension)

No iOS, receber compartilhamentos exige uma **Share Extension** + **App Group**.
É mais trabalhoso e feito no Xcode. Passos resumidos (siga o README oficial do
pacote para os arquivos exatos da versão `1.8.x`):

1. Xcode → File → New → Target → **Share Extension** (ex.: `Share Extension`).
2. Em **Signing & Capabilities**, adicione o mesmo **App Group**
   (`group.com.onesaver`) ao target **Runner** e ao target da extensão.
3. Substitua o `ShareViewController` da extensão pela classe do pacote
   (`RSIShareViewController`) conforme o README.
4. No `Info.plist` da extensão, configure `NSExtensionActivationRule` para
   aceitar **URLs e texto** (`NSExtensionActivationSupportsWebURLWithMaxCount`
   e `...SupportsTextWithMaxCount`).
5. Adicione o **URL scheme** `ShareMedia-$(PRODUCT_BUNDLE_IDENTIFIER)` ao
   `Runner/Info.plist`.
6. Defina o App Group id no `Runner/Info.plist` (chave `AppGroupId`).

Referência: https://pub.dev/packages/receive_sharing_intent (seção iOS).

---

## Como testar (Android)
1. `flutter run`
2. App do Instagram → reel público → **Compartilhar** → escolha **OneSaver**.
3. Esperado: OneSaver abre, mostra "Buscando..." e vai para a pré-visualização
   (no modo STUB, mostra o vídeo de exemplo independentemente do link).
