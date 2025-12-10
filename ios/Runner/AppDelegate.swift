import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let mapsKey = Bundle.main.object(forInfoDictionaryKey: "MAPS_API_KEY") as? String ?? ""
    let placesKey = Bundle.main.object(forInfoDictionaryKey: "PLACES_API_KEY") as? String ?? ""

    GMSServices.provideAPIKey(mapsKey)
    GMSPlacesClient.provideAPIKey(placesKey)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}