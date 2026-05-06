import SwiftUI
#if os(iOS)
import GoogleMobileAds
import UIKit

/// SwiftUI wrapper for a Google AdMob banner ad.
/// Uses UIViewControllerRepresentable so the banner has a proper rootViewController in the hierarchy.
struct BannerAdView: UIViewControllerRepresentable {
    /// Test ID for simulator; production on device.
    private static let testBannerID = "ca-app-pub-3940256099942544/2435281174"
    private static let productionBannerID = "ca-app-pub-3565666509316178/4180986101"

    private let adUnitID: String
    private let adSize: AdSize

    static var preferredAdSize: AdSize {
        let width = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .bounds
            .inset(by: UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)?
                .safeAreaInsets ?? .zero)
            .width ?? UIScreen.main.bounds.width

        return largeAnchoredAdaptiveBanner(width: max(320, width))
    }

    static var preferredHeight: CGFloat {
        preferredAdSize.size.height
    }

    init(adUnitID: String? = nil, adSize: AdSize = Self.preferredAdSize) {
        #if targetEnvironment(simulator)
        self.adUnitID = adUnitID ?? Self.testBannerID
        #else
        self.adUnitID = adUnitID ?? Self.productionBannerID
        #endif
        self.adSize = adSize
    }

    func makeUIViewController(context: Context) -> BannerAdHostController {
        BannerAdHostController(adUnitID: adUnitID, adSize: adSize, delegate: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: BannerAdHostController, context: Context) {
        uiViewController.updateAdSize(adSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("✅ [AdMob] Banner ad loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("⚠️ [AdMob] Banner failed to load: \(error.localizedDescription)")
        }
    }
}

/// Hosts the banner in a view controller so rootViewController is valid.
final class BannerAdHostController: UIViewController {
    private let adUnitID: String
    private weak var delegate: BannerViewDelegate?
    private var bannerView: BannerView?
    private var currentAdSize: AdSize

    init(adUnitID: String, adSize: AdSize, delegate: BannerViewDelegate) {
        self.adUnitID = adUnitID
        self.currentAdSize = adSize
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let banner = BannerView(adSize: currentAdSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = self
        banner.delegate = delegate
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        bannerView = banner

        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            banner.topAnchor.constraint(equalTo: view.topAnchor),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        banner.load(Request())
    }

    func updateAdSize(_ adSize: AdSize) {
        guard !isAdSizeEqualToSize(size1: currentAdSize, size2: adSize) else { return }
        currentAdSize = adSize
        bannerView?.adSize = adSize
        bannerView?.load(Request())
    }
}
#else
/// Placeholder for macOS - AdMob not supported
struct BannerAdView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
