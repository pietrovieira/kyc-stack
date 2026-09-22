# FaceTec - kyc-app (Flutter)

## Getting Started

1. **Backend**: configure `kyc-backend/.env` com chaves de https://dev.facetec.com (Configuration Wizard)
2. **FaceTec Server**: rode `docker compose up facetec-server` e valide `http://localhost:8080/status`
3. **Flutter**:

```bash
cd kyc-app
flutter pub get
flutter run --dart-define=BACKEND_URL=http://localhost:3000
# ou para device físico:
flutter run --dart-define=BACKEND_URL=http://SEU_IP:3000
```

### Instalar Device SDK nativo (para câmera real)

O app atual vem com mock (sem câmera) para compilar sem ZIP.

Para habilitar 3D FaceScan real:

1. No portal `dev.facetec.com` -> Download Config File -> escolha `Flutter` ou `Android/iOS/Browser`
2. Descompacte e siga `getting-started#additional-run-steps`:
   - Android: adicione `facetec_sdk.aar` em `android/app/libs/` + config em `android/app/src/main/assets/`
   - iOS: adicione `FaceTecSDK.xcframework` via CocoaPods
   - Web: copie `FaceTecSDK.js` para `web/` e importe em `web/index.html`

3. No `pubspec.yaml`, descomente:
```yaml
facetec_sdk: ^9.6.88
```

4. Em `lib/services/facetec_service.dart`, descomente os blocos `FaceTecSDK.initializeInDevelopmentMode` e `FaceTecSession`.

Exemplo real:
```dart
final config = await FacetecService().fetchConfig();
await FaceTecSDK.initializeInDevelopmentMode(
  config.deviceKeyIdentifier,
  config.publicFaceScanEncryptionKey,
);

final processor = FaceTecFaceScanProcessor(
  sessionToken: 'token-do-backend', // futuro: GET /api/facetec/session-token
  externalDatabaseRefID: 'cpf_123',
);
FaceTecSession(processor, sessionToken);
// processor callback retorna requestBlob -> FacetecService().processRequest(...)
```

Permissões já configuradas:
- Android: `CAMERA` em `AndroidManifest.xml`
- iOS: `NSCameraUsageDescription` em `Info.plist`

### Telas

- `lib/screens/kyc_screen.dart` - 5 fluxos FaceTec (Liveness, Enrollment, Verification, Photo ID, ID Scan)
- `lib/services/facetec_service.dart` - proxy para `kyc-backend/api/facetec/*`
- `lib/config/app_config.dart` - `BACKEND_URL` via --dart-define
