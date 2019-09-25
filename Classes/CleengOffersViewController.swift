//
//  CleengOffersViewController.swift
//  CleengLogin
//
//  Created by Yossi Avramov on 03/06/2018.
//

import UIKit
import StoreKit
import ZappPlugins

let maximumNumberOfItemsFullyVisibleInIpad: Int = 3

class CleengOffersViewController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, CleengOfferCollectionViewCellDelegate, CleengLoginAndSubscriptionProtocol {
    
    weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            if isViewLoaded {
                updateHeaderView()
                configureViews()
                if collectionView.numberOfSections > 0 && collectionView.numberOfItems(inSection: 0) > 0 {
                    collectionView.reloadDataTruelyWorking()
                }
            }
        }
    }
    
    @objc @IBOutlet fileprivate weak var backButton: UIButton!
    @objc @IBOutlet fileprivate weak var closeButton: UIButton!
    
    @objc @IBOutlet fileprivate weak var backgroundImageView: UIImageView!
    @objc @IBOutlet fileprivate weak var backgroundOverlay: UIView!
    
    @objc @IBOutlet weak var collectionView: UICollectionView!
    
    @objc @IBOutlet private weak var headerLabel: UILabel?
    @objc @IBOutlet fileprivate weak var goToSignInButton: UIButton?
    
    @objc @IBOutlet fileprivate weak var topGradientContainerView: UIView!
    @objc @IBOutlet fileprivate weak var topGradientImageView: UIImageView!
    
    @objc @IBOutlet private weak var paymentDetailsTextView: ContentSizeObservableTextView!
    @objc @IBOutlet private weak var paymentDetailsTextViewTopSpacing: NSLayoutConstraint!
    
    @objc @IBOutlet private weak var loadingAndMessageContainerView: UIView!
    @objc @IBOutlet private weak var loadingActivityIndicator: UIActivityIndicatorView!
    @objc @IBOutlet private weak var errorMessageLabel: UILabel!
    @objc @IBOutlet private weak var errorMessageButton: UIButton!
    private var errorMessageButtonAction: (() -> Void)?
    
    private var isLoadingProducts = false {
        didSet {
            if isLoadingProducts {
                errorMessageLabel.isHidden = true
                loadingActivityIndicator.isHidden = false
                loadingAndMessageContainerView.isHidden = false
                errorMessageButton.isHidden = true
                
                loadingActivityIndicator.startAnimating()
                errorMessageButtonAction = nil
            } else {
                loadingActivityIndicator.stopAnimating()
                loadingActivityIndicator.isHidden = true
                loadingAndMessageContainerView.isHidden = errorMessageLabel.isHidden
            }
        }
    }
    
    private var items: [(offer: CleengOffer, product: SKProduct)]?
    
    //MARK: - Override-s
    override func viewDidLoad() {
        super.viewDidLoad()
        
        backButton.setTitle(nil, for: .normal)
        backButton.backgroundColor = UIColor.clear
        
        closeButton.setTitle(nil, for: .normal)
        closeButton.backgroundColor = UIColor.clear
        
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        layout.estimatedItemSize = CGSize(width: 300, height: 300)
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        
        topGradientContainerView.alpha = 0
        
        loadingAndMessageContainerView.isHidden = true
        loadingActivityIndicator.isHidden = true
        loadingActivityIndicator.stopAnimating()
        errorMessageLabel.isHidden = true
        
        if let nav = navigationController , nav.viewControllers.first === self {
            backButton.isHidden = true
        }
        
        paymentDetailsTextView.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        paymentDetailsTextView.onContentSizeChange = { [unowned self] in
            let textView = self.paymentDetailsTextView!
            let size = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: CGFloat.greatestFiniteMagnitude))
            var topPadding = max((textView.bounds.height - (size.height * textView.zoomScale)) * 0.5 - 3, 0)
            topPadding = round(topPadding * 2) * 0.5
            self.paymentDetailsTextViewTopSpacing.constant = topPadding
        }
        
        configureViews()
        updateHeaderView()
        loadStoreProducts()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateHeaderView()
        loadStoreProducts()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UI_USER_INTERFACE_IDIOM() == .phone {
            return .portrait
        } else {
            return .landscape
        }
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if let nav = parent as? UINavigationController , nav.viewControllers.isEmpty || nav.viewControllers.first === self {
            backButton?.isHidden = true
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if (previousTraitCollection == nil || previousTraitCollection!.horizontalSizeClass == .unspecified || previousTraitCollection!.verticalSizeClass == .unspecified) && isViewLoaded {
            updateCollectionViewDirection()
            updatedCellSize()
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        let updatedScrollDirection: UICollectionView.ScrollDirection
        if newCollection.horizontalSizeClass == .regular && newCollection.verticalSizeClass == .regular {
            updatedScrollDirection = .horizontal
            topGradientContainerView.isHidden = true
        } else {
            updatedScrollDirection = .vertical
            topGradientContainerView.isHidden = (topGradientImageView.image == nil)
        }
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        if layout.scrollDirection != updatedScrollDirection {
            coordinator.animateAlongsideTransition(in: collectionView, animation: { _ in
                if self.topGradientContainerView.isHidden == false {
                    self.updateCollectionViewGradients(continuous: false, animated: false)
                }
                
                layout.scrollDirection = updatedScrollDirection
                if updatedScrollDirection == .horizontal {
                    layout.sectionInset = UIEdgeInsets(top: 58, left: 40, bottom: 300, right: 40)
                    layout.minimumLineSpacing = 18
                    layout.minimumInteritemSpacing = 18
                    layout.headerReferenceSize = .zero
                } else {
                    layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
                    layout.minimumLineSpacing = 8
                    layout.minimumInteritemSpacing = 8
                    layout.headerReferenceSize.height = 100
                }
                layout.invalidateLayout()
            }, completion: nil)
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updatedCellSize()
        updateCollectionViewGradients(continuous: false, animated: false)
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    private func updateCollectionViewDirection() {
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        if traitCollection.horizontalSizeClass == .regular && traitCollection.verticalSizeClass == .regular {
            if layout.scrollDirection == .vertical {
                layout.scrollDirection = .horizontal
                layout.sectionInset = UIEdgeInsets(top: 58, left: 40, bottom: 300, right: 40)
                layout.minimumLineSpacing = 18
                layout.minimumInteritemSpacing = 18
                layout.headerReferenceSize = .zero
                topGradientContainerView.isHidden = true
            }
        } else {
            if layout.scrollDirection == .horizontal {
                layout.scrollDirection = .vertical
                layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
                layout.minimumLineSpacing = 8
                layout.minimumInteritemSpacing = 8
                layout.headerReferenceSize.height = 100
                topGradientContainerView.isHidden = (topGradientImageView.image == nil)
            }
        }
    }
    
    private func updatedCellSize() {
        
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        if layout.scrollDirection == .vertical {
            layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
            layout.minimumLineSpacing = 8
            layout.minimumInteritemSpacing = 8
            layout.estimatedItemSize = CGSize(width: 302, height: 144)
        } else {
            layout.sectionInset = UIEdgeInsets(top: 58, left: 40, bottom: 300, right: 40)
            layout.minimumLineSpacing = 18
            layout.minimumInteritemSpacing = 18
            layout.estimatedItemSize = CGSize(width: 302, height: 237)
        }
    }
    
    private func configureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        backgroundImageView.setupCleengBackground(with: stylesManager)
        backgroundOverlay.setZappStyle(using: stylesManager, withBackgroundColor: .backgroundColor)
        closeButton.setZappStyle(using: stylesManager, withIconAsset: .closeIcon)
        backButton.setZappStyle(using: stylesManager, withIconAsset: .backIcon)
        
        paymentDetailsTextView.superview?.setZappStyle(using: stylesManager, withBackgroundColor: .bottomLegalBackgroundColor)
        paymentDetailsTextView.textAlignment = .center
        paymentDetailsTextView.setZappStyle(using: stylesManager,
                                         text: manager?.localizedString(for: .legal) ?? "",
                                         style: .legalText)
        DispatchQueue.main.async {
            self.paymentDetailsTextView.contentOffset = .zero
        }
        
        topGradientImageView.setZappStyle(using: stylesManager, withAsset: .subscriptionShadow, stretchableImage: true)
        loadingActivityIndicator.setZappStyle(using: stylesManager, withColor: .loadingIndicatorColor)
        errorMessageLabel.setZappStyle(using: stylesManager,
                                       text: nil,
                                       style: .alertDescription)
        
        headerLabel?.setZappStyle(using: stylesManager,
                                 text: manager?.localizedString(for: .subscriptionTitle),
                                 style: .loginTitle)
        
        goToSignInButton?.setAttributedZappStyle(using: stylesManager,
                                                attributedTitle: [
                                                    (style: .actionDescription,
                                                     string: manager?.localizedString(for: .haveAccount) ?? NSLocalizedString("Already have an account?", comment: "Already have an account?"),
                                                     additionalAttributes: nil),
                                                    (style: .actionText,
                                                     string: manager?.localizedString(for: .signIn) ?? NSLocalizedString("Sign In", comment: "Sign In"),
                                                     additionalAttributes: nil)
            ])
        
        topGradientContainerView.isHidden = (topGradientImageView.image == nil)
    }
    
    private func updateHeaderView() {
        guard let manager = manager else { return }
        
        goToSignInButton?.isHidden = (manager.api.cleengLoginState == .loggedIn)
        
        
        for v in collectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
            (v as? CleengOfferCollectionHeaderView)?.manager = manager
        }
    }
    
    private func loadStoreProducts() {
        
        guard !isLoadingProducts else { return }
        guard let api = manager?.api else { return }
        guard items?.isEmpty ?? true else { return }
        
        isLoadingProducts = true
        api.loadStoreProducts { [weak self] (items, error) in
            guard let strongSelf = self else { return }
            
            strongSelf.isLoadingProducts = false
            if let items = items , items.isEmpty == false {
                strongSelf.items = items
                //for digicel login plugin for adding new offer to collectionView
                if((strongSelf.manager?.digicelUser)!){
                    var newDigiceloffer = items.first?.offer
                    newDigiceloffer?.id = "digicelUserOffer"
                    strongSelf.items?.append((offer: newDigiceloffer!, product: (items.first?.product)!))
                }
                strongSelf.collectionView.reloadDataTruelyWorking()
            } else {
                strongSelf.items = nil
                strongSelf.collectionView.reloadDataTruelyWorking()
                
                if let error = error as NSError? {
                    let messageKey = ZappCleengLoginLocalization.errorMessageLocalizationKey(forCode: error.code)
                    strongSelf.errorMessageLabel.text = strongSelf.manager?.localizedString(for: messageKey, defaultString: NSLocalizedString("There're no available subsriptions to purchase", comment: "There're no available subsriptions to purchase"))
                    strongSelf.errorMessageLabel.isHidden = false
                } else {
                    strongSelf.errorMessageLabel.text = strongSelf.manager?.localizedString(for: .errorInternalMessage, defaultString: NSLocalizedString("There're no available subsriptions to purchase", comment: "There're no available subsriptions to purchase"))
                    strongSelf.errorMessageLabel.isHidden = false
                }
            }
        }
    }
    
    //MARK: - Actions
    @objc @IBAction fileprivate func back() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc @IBAction fileprivate func close() {
        manager?.userDidSelectToClose()
    }
    
    @objc @IBAction private func goToSignIn() {
        manager?.showSignIn(animated: true, makeRoot: false)
    }
    
    @objc @IBAction private func errorButtonTap() {
        errorMessageButtonAction?()
    }
    
    //MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isLoadingProducts {
            return 0
        } else {
            return (items?.count ?? 0)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OfferCell", for: indexPath) as! CleengOfferCollectionViewCell
        let item = items![indexPath.item]
    
        //for digicel login plugin for adding new offer to collectionView or hidding all offers
        if let showSubscription = manager?.localizedString(for: .showSubscriptionsDigicel){
            if(showSubscription == "0"){
                cell.isHidden = true
                if(item.offer.id == "digicelUserOffer"){
                      cell.isHidden = false
                }
            }
        }
        
        let redeem: String?
        if manager?.isCouponRedeemAvailable ?? false {
            redeem = manager?.localizedString(for: .sbscriptionsRedeemCouponAction) ?? NSLocalizedString("Redeem Code", comment: "Redeem Code")
        } else {
            redeem = nil
        }
        
        //check if the item is for digicel user or not then customize the cell accordingly
        if (item.offer.id == "digicelUserOffer"){
            cell.configureForDigicelView(offer: item.offer, product: item.product, title: manager?.localizedString(for: .digicelSubscriptionTitle) ?? "Digicel", desc: manager?.localizedString(for: .digicelSubscriptionText) ?? "To get Digicel Package", actionText: manager?.localizedString(for: .digicelSubscriptionSubmit_btn) ?? "CliCK HERE!", subscriptionUrl: manager?.localizedString(for: .digicelSubscriptionUrl) ?? "http://p.mydigicel.net")
        }else{
            cell.configure(offer: item.offer, product: item.product, subscribeAction: (manager?.localizedString(for: .subscribeAction) ?? NSLocalizedString("SUBSCRIBE FOR", comment: "SUBSCRIBE FOR")), tagText: manager?.offerLocalizedTagString(for: item.offer.id), redeemAction: redeem)
        }
        
        cell.delegate = self
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! CleengOfferCollectionHeaderView
        header.manager = manager
        return header
    }
    
    //MARK: - UICollectionViewDelegate
    //MARK: - UIScrollViewDelegate
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCollectionViewGradients(continuous: scrollView.isDragging, animated: false)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateCollectionViewGradients(continuous: false, animated: true)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCollectionViewGradients(continuous: false, animated: true)
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateCollectionViewGradients(continuous: false, animated: true)
    }
    
    private func updateCollectionViewGradients(continuous: Bool, animated: Bool) {
        if topGradientContainerView.isHidden == false {
            var alpha: CGFloat = max(0, min(1, (collectionView.bounds.minY / (topGradientImageView.bounds.height * 1.5))))
            if !continuous {
                alpha = (alpha < 0.2) ? 0 : 1
            }
            
            if animated {
                UIView.animate(withDuration: 0.15, delay: 0, options: [.beginFromCurrentState], animations: {
                    self.topGradientContainerView.alpha = alpha
                }, completion: nil)
            }
            else {
                self.topGradientContainerView.alpha = alpha
            }
        }
    }
    
    //MARK: - CleengOfferCollectionViewCellDelegate
    func cleengOfferCollectionViewCell(_ cell: CleengOfferCollectionViewCell, didSelectToSubscribeWithProduct product: SKProduct, offer: CleengOffer) {
        guard let manager = manager else { return }
        
        guard manager.api.cleengLoginState == .loggedIn else {
            manager.purhcaseOnLogin = .buy(product: product, offer: offer)
            manager.showSignUp(animated: true, makeRoot: true)
            return
        }
        
        manager.showLoading(for: self)
        manager.api.purchaseProduct(product, forOffer: offer, completion: { [weak self, weak manager] (result) in
            guard let strongSelf = self, let manager = manager else { return }
            
            switch result {
            case .succeeded:
                manager.hideLoading(for: strongSelf)
                if manager.api.hasAuthorizationTokenForCurrentItem {
					manager.authenticated(with: .inAppPurchase, showAlert: true)
                } else {
                    assert(false, "That shouldn't happen. The user purchased a subscription and doesn't have token for it")
                }
            case .fatalFailure(let error):
                manager.hideLoading(for: strongSelf)
                manager.fatalErrorOccured(withTitle: manager.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: error.localizedDescription, suggestContact: true)
            case .failedButCanRetry(let error, let retry, let userSelectNotToRetry):
                if let err = (error as? SKError) , err.code == SKError.Code.paymentCancelled {
                    manager.hideLoading(for: strongSelf)
                    userSelectNotToRetry()
                    return
                }
                
                let alert = UIAlertController(title: manager.localizedString(for: .errorInternalTitle, defaultString: NSLocalizedString("Error", comment: "Error")), message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertCancelAction, defaultString: NSLocalizedString("Cancel", comment: "Cancel")), style: .cancel, handler: { _ in
                    manager.hideLoading(for: strongSelf)
                    userSelectNotToRetry()
                }))
                
                alert.addAction(UIAlertAction(title: manager.localizedString(for: .alertRetryAction, defaultString: NSLocalizedString("Retry", comment: "Retry")), style: .default, handler: { _ in
                    retry()
                }))
                
                strongSelf.present(alert, animated: true, completion: nil)
            }
        })
    }
    
    func cleengOfferCollectionViewCell(_ cell: CleengOfferCollectionViewCell, didSelectToRedeemCouponForOffer offer: CleengOffer) {
        guard let manager = manager else { return }
        
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "RedeemCoupon") as? CleengRedeemCouponViewController else { return }
        
        vc.manager = manager
        vc.offer = offer
        
        navigationController?.pushViewController(vc, animated: true)
    }
}

protocol CleengOfferCollectionViewCellDelegate : NSObjectProtocol {
    var collectionView: UICollectionView! { get }
    func cleengOfferCollectionViewCell(_ cell: CleengOfferCollectionViewCell, didSelectToSubscribeWithProduct product: SKProduct, offer: CleengOffer)
    func cleengOfferCollectionViewCell(_ cell: CleengOfferCollectionViewCell, didSelectToRedeemCouponForOffer offer: CleengOffer)
}

class CleengOfferCollectionViewCell : UICollectionViewCell {
    @objc @IBOutlet fileprivate weak var backgroundImageView: UIImageView!
    
    @objc @IBOutlet fileprivate weak var tagLabel: UILabel!
    @objc @IBOutlet fileprivate weak var tagImageView: UIImageView!
    
    @objc @IBOutlet fileprivate weak var titleLabel: UILabel!
    @objc @IBOutlet fileprivate weak var descriptionLabel: UILabel!
    @objc @IBOutlet fileprivate weak var subscribeButton: UIButton!
    @objc @IBOutlet fileprivate weak var subscribeButtonHeight: NSLayoutConstraint!
    
    @objc @IBOutlet fileprivate weak var redeemCouponButton: UIButton!
    @objc @IBOutlet fileprivate weak var redeemCouponButtonHeight: NSLayoutConstraint!
    
    @objc @IBOutlet fileprivate var descriptionLabelSpacingFromPriceLabel: NSLayoutConstraint!
    
    fileprivate var offerAndProduct: (offer: CleengOffer, product: SKProduct)!
    
    fileprivate weak var delegate: CleengOfferCollectionViewCellDelegate?
    
    private var digicelSubscriptionUrl: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        offerAndProduct = nil
        
        subscribeButton.titleLabel?.numberOfLines = 2
        redeemCouponButton.titleLabel?.numberOfLines = 2
        descriptionLabelSpacingFromPriceLabel.priority = .required
    }
    
    func configure(offer: CleengOffer, product: SKProduct, subscribeAction: String, tagText: String?, redeemAction: String?) {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        offerAndProduct = (offer: offer, product: product)
        
        if offer.isPromoted == true {
            backgroundImageView.setZappStyle(using: stylesManager,
                                             withAsset: .subscriptionBackgroundPromoted,
                                             stretchableImage: true)
        } else {
            backgroundImageView.setZappStyle(using: stylesManager,
                                             withAsset: .subscriptionBackground,
                                             stretchableImage: true)
        }
        
        subscribeButton.setZappStyle(using: stylesManager,
                                     backgroundAsset: .subscribeButtonBackground,
                                     title: "\(subscribeAction) \(product.formattedPrice)",
            style: .subscriptionText)
        
        let image = subscribeButton.backgroundImage(for: .normal)
        subscribeButtonHeight.constant = max(image?.size.height ?? 0, 37)
        
        if let redeemAction = redeemAction {
            redeemCouponButton.isHidden = false
            
            let attr: [NSAttributedString.Key : Any] = [.underlineStyle : NSUnderlineStyle.single.rawValue]
            redeemCouponButton.setAttributedZappStyle(using: stylesManager,
                                                      attributedTitle: [(style: .cleengLoginVoucher, string: redeemAction, additionalAttributes: attr)],
                                                      forState: .normal)
            
            redeemCouponButton.setZappStyle(using: stylesManager,
                                            title: redeemAction,
                                            style: .subscriptionText)
        } else {
            redeemCouponButton.isHidden = true
        }
        
        tagLabel.setZappStyle(using: stylesManager, style: .subscriptionTagText)
        tagImageView.setZappStyle(using: stylesManager,
                                  withAsset: .subscriptionPromotion,
                                  stretchableImage: true)
        
        tagLabel.text = tagText

        tagImageView.superview?.isHidden = (tagText == nil && tagImageView.image == nil) || offer.shouldRemovePromotionIcon
        
        titleLabel.setZappStyle(using: stylesManager,
                                text: product.localizedTitle,
                                style: .subscriptionTitle)
        descriptionLabel.setZappStyle(using: stylesManager,
                                      text: product.localizedDescription,
                                      style: .subscriptionDetails)
    }
    
    //for digicel login plugin configure the cell for digicel user offer
    func configureForDigicelView(offer: CleengOffer, product: SKProduct, title: String , desc: String, actionText: String, subscriptionUrl: String){
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
      
        offerAndProduct = (offer: offer, product: product)
        
        backgroundImageView.setZappStyle(using: stylesManager,
                                         withAsset: .subscriptionBackground,
                                         stretchableImage: true)
        
         redeemCouponButton.isHidden = true
         tagImageView.superview?.isHidden = true
        
        titleLabel.setZappStyle(using: stylesManager,
                                text: title,
                                style: .subscriptionTitle)
        descriptionLabel.setZappStyle(using: stylesManager,
                                      text: desc,
                                      style: .subscriptionDetails)
        subscribeButton.setZappStyle(using: stylesManager,
                                     backgroundAsset: .subscribeButtonBackground,
                                     title: actionText,
                                     style: .subscriptionText)
        
        self.digicelSubscriptionUrl = subscriptionUrl
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        delegate = nil
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        var size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        size.width = targetSize.width
        size.height = ceil(size.height)
        return size
    }
    
    override func systemLayoutSizeFitting(_ targetSize: CGSize, withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority, verticalFittingPriority: UILayoutPriority) -> CGSize {
        var size = super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        size.width = targetSize.width
        size.height = ceil(size.height)
        return size
    }
    
    @objc @IBAction private func subscribe() {
        guard let offerAndProduct = offerAndProduct else {
            return
        }
        //check if the offer is for digicel user used in digicel login plugin
        if(offerAndProduct.offer.id == "digicelUserOffer"){
            if let url  = self.digicelSubscriptionUrl{
                let url = URL(string: url)
                UIApplication.shared.open(url!, options: [:])
            }
        }else{
            delegate?.cleengOfferCollectionViewCell(self, didSelectToSubscribeWithProduct: offerAndProduct.product, offer: offerAndProduct.offer)
        }
    }
    
    @objc @IBAction private func redeem() {
        guard let offerAndProduct = offerAndProduct else {
            return
        }
        
        delegate?.cleengOfferCollectionViewCell(self, didSelectToRedeemCouponForOffer: offerAndProduct.offer)
    }
}

class CleengOfferCollectionHeaderView : UICollectionReusableView {
    @objc @IBOutlet private weak var headerLabel: UILabel!
    @objc @IBOutlet private weak var goToSignInButton: UIButton!
    @objc @IBOutlet private var headerLabelSpaceFromGoToSignInButton: NSLayoutConstraint!
    @objc @IBOutlet private var goToSignInButtonBottomSpacing: NSLayoutConstraint!
    @objc @IBOutlet private var headerLabelBottomSpacing: NSLayoutConstraint!
    
    weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            guard let _ = headerLabel else { return }
            
            configureViews()
            updateViews()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        updateViews()
        configureViews()
        headerLabelSpaceFromGoToSignInButton.priority = .required
        headerLabelBottomSpacing.isActive = false
        headerLabelBottomSpacing.priority = .required
    }
    
    fileprivate func configureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        headerLabel.setZappStyle(using: stylesManager,
                                 text: manager?.localizedString(for: .subscriptionTitle),
                                 style: .loginTitle)
        
        goToSignInButton.setAttributedZappStyle(using: stylesManager,
                                              attributedTitle: [
                                                (style: .actionDescription,
                                                 string: manager?.localizedString(for: .haveAccount) ?? NSLocalizedString("Already have an account?", comment: "Already have an account?"),
                                                 additionalAttributes: nil),
                                                (style: .actionText,
                                                 string: manager?.localizedString(for: .signIn) ?? NSLocalizedString("Sign In", comment: "Sign In"),
                                                 additionalAttributes: nil)
            ])
    }
    
    fileprivate func updateViews() {
        guard let manager = manager else { return }
        
        goToSignInButton.isHidden = (manager.api.cleengLoginState == .loggedIn)
        if(manager.digicelUser){
            goToSignInButton.isHidden = true
        }
        headerLabelSpaceFromGoToSignInButton.isActive = !goToSignInButton.isHidden
        goToSignInButtonBottomSpacing.isActive = headerLabelSpaceFromGoToSignInButton.isActive
        headerLabelBottomSpacing.isActive = !headerLabelSpaceFromGoToSignInButton.isActive
    }
    
    @objc @IBAction private func goToSignIn() {
        manager?.showSignIn(animated: true, makeRoot: false)
    }
}

private let priceFormatter: NumberFormatter = NumberFormatter()
extension SKProduct {
    var formattedPrice: String {
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = self.priceLocale
        return priceFormatter.string(from: self.price)!
    }
}

class MyFlowLayout : UICollectionViewFlowLayout {
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let elements = super.layoutAttributesForElements(in: rect) else { return nil }
        
        guard let collectionView = self.collectionView else { return elements }
        
        if collectionView.traitCollection.horizontalSizeClass == .regular && collectionView.traitCollection.verticalSizeClass == .regular && elements.isEmpty == false {
            let collectionViewBounds = collectionView.bounds
            let tempRect = CGRect(x: 0, y: sectionInset.top, width: 0, height: (collectionViewBounds.height - sectionInset.top) * 0.4)
            let defaultCenterY = tempRect.centerY
            
            let numberOfItems = collectionView.numberOfItems(inSection: 0)
            let newElements = elements.map({ (attr) -> UICollectionViewLayoutAttributes in
                if attr.representedElementCategory == .cell {
                    let newAttr = attr.copy() as! UICollectionViewLayoutAttributes
                    newAttr.frame.size.height = max(newAttr.frame.height, (collectionViewBounds.height - sectionInset.top) * 0.4)
                    var rect = CGRect(center: CGPoint(x: newAttr.center.x, y: defaultCenterY), size: newAttr.size)
                    if numberOfItems < maximumNumberOfItemsFullyVisibleInIpad {
                        if numberOfItems == 1 {
                            rect.centerX = collectionViewBounds.midX
                        } else {
                            let actualLeftSpacing = (collectionViewBounds.width - (estimatedItemSize.width * CGFloat(numberOfItems)) - (minimumInteritemSpacing * CGFloat(numberOfItems - 1))) * 0.5
                            if actualLeftSpacing > sectionInset.left {
                                rect.origin.x += (actualLeftSpacing - sectionInset.left)
                            }
                        }
                    }
                    newAttr.frame = rect
                    return newAttr
                }
                else { return attr }
            })
            
            return newElements
        } else {
            return elements
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attr = super.layoutAttributesForItem(at: indexPath) else { return nil }
        
        guard let collectionView = self.collectionView else { return attr }
        
        if collectionView.traitCollection.horizontalSizeClass == .regular && collectionView.traitCollection.verticalSizeClass == .regular {
            let collectionViewBounds = collectionView.bounds
            
            let tempRect = CGRect(x: 0, y: sectionInset.top, width: 0, height: (collectionViewBounds.height - sectionInset.top) * 0.4)
            let defaultCenterY = tempRect.centerY
            
            let newAttr = attr.copy() as! UICollectionViewLayoutAttributes
            newAttr.frame.size.height = max(newAttr.frame.height, (collectionViewBounds.height - sectionInset.top) * 0.4)
            var rect = CGRect(center: CGPoint(x: newAttr.center.x, y: defaultCenterY), size: newAttr.size)
            
            let numberOfItems = collectionView.numberOfItems(inSection: 0)
            if numberOfItems < maximumNumberOfItemsFullyVisibleInIpad {
                if numberOfItems == 1 {
                    rect.centerX = collectionViewBounds.midX
                } else {
                    let actualLeftSpacing = (collectionViewBounds.width - (estimatedItemSize.width * CGFloat(numberOfItems)) - (minimumInteritemSpacing * CGFloat(numberOfItems - 1))) * 0.5
                    if actualLeftSpacing > sectionInset.left {
                        rect.origin.x += (actualLeftSpacing - sectionInset.left)
                    }
                }
            }
            newAttr.frame = rect
            return newAttr
        }
        else { return attr }
    }
    override func shouldInvalidateLayout(forPreferredLayoutAttributes preferredAttributes: UICollectionViewLayoutAttributes, withOriginalAttributes originalAttributes: UICollectionViewLayoutAttributes) -> Bool {
        guard preferredAttributes.representedElementCategory == .cell else {
            if preferredAttributes.representedElementCategory == .supplementaryView
                && preferredAttributes.representedElementKind == UICollectionView.elementKindSectionHeader
                && preferredAttributes.size.height != originalAttributes.size.height
                && self.scrollDirection == .vertical {
                
                //'UICollectionViewFlowLayout' isn't supporting self-sizing for header/footer. Trying to invalidate header/foorer for different size cause a crash. This is a hack to support self-sizing for header
                DispatchQueue.main.async {
                    if self.scrollDirection == .vertical {
                        self.headerReferenceSize.height = preferredAttributes.size.height
                    }
                }
            }
            
            return super.shouldInvalidateLayout(forPreferredLayoutAttributes: preferredAttributes, withOriginalAttributes: originalAttributes)
        }
        
        guard let collectionView = self.collectionView else {
            return super.shouldInvalidateLayout(forPreferredLayoutAttributes: preferredAttributes, withOriginalAttributes: originalAttributes)
        }
        
        if collectionView.traitCollection.horizontalSizeClass == .regular && collectionView.traitCollection.verticalSizeClass == .regular {
            return false
        } else {
            preferredAttributes.size.width = originalAttributes.size.width
            preferredAttributes.center.x = originalAttributes.center.x
            return super.shouldInvalidateLayout(forPreferredLayoutAttributes: preferredAttributes, withOriginalAttributes: originalAttributes)
        }
    }
}

class ContentSizeObservableTextView : UITextView {
    var onContentSizeChange: (() -> Void)?
    override var contentSize: CGSize {
        didSet {
            onContentSizeChange?()
        }
    }
}
