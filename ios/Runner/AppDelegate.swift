import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "br.gov.itapema.cami/media",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "saveSnapshot" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let typedData = arguments["bytes"] as? FlutterStandardTypedData
      else {
        result(FlutterError(code: "invalid_snapshot", message: "Imagem inválida.", details: nil))
        return
      }
      self?.saveSnapshot(typedData.data, result: result)
    }
  }

  private func saveSnapshot(_ imageData: Data, result: @escaping FlutterResult) {
    let authorization: PHAuthorizationStatus
    if #available(iOS 14, *) {
      authorization = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    } else {
      authorization = PHPhotoLibrary.authorizationStatus()
    }

    if authorization == .notDetermined {
      if #available(iOS 14, *) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] _ in
          self?.saveSnapshot(imageData, result: result)
        }
      } else {
        PHPhotoLibrary.requestAuthorization { [weak self] _ in
          self?.saveSnapshot(imageData, result: result)
        }
      }
      return
    }

    let canAddPhoto: Bool
    if #available(iOS 14, *) {
      canAddPhoto = authorization == .authorized || authorization == .limited
    } else {
      canAddPhoto = authorization == .authorized
    }
    guard canAddPhoto else {
      result(FlutterError(
        code: "photos_permission_denied",
        message: "Permissão para salvar fotos foi negada.",
        details: nil
      ))
      return
    }

    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCreationRequest.creationRequestForAsset()
      request.addResource(with: .photo, data: imageData, options: nil)
    }) { success, error in
      DispatchQueue.main.async {
        if success {
          result("Fotos > CAMI")
        } else {
          result(FlutterError(
            code: "snapshot_save_failed",
            message: "Não foi possível salvar o snapshot.",
            details: error?.localizedDescription
          ))
        }
      }
    }
  }
}
