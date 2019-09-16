//
//  CleengLoginAlertController.swift
//  AFNetworking
//
//  Created by Yossi Avramov on 06/06/2018.
//

import UIKit
import ZappPlugins

class CleengLoginAlertController : UIViewController, UIViewControllerTransitioningDelegate, CleengLoginAndSubscriptionProtocol {
    
    @objc @IBOutlet private weak var alertBackgroundImageView: UIImageView!
    @objc @IBOutlet private weak var titleLabel: UILabel!
    @objc @IBOutlet private weak var descriptionLabel: UILabel!
    @objc @IBOutlet private weak var actionButton: UIButton!
    
    private var onAction: (() -> Void)?
    weak var manager: CleengLoginAndSubscriptionManager? {
        didSet {
            if isViewLoaded {
                configureViews()
            }
        }
    }
    
    var alertTitle: String? {
        get { return isViewLoaded ? titleLabel.text : nil }
        set {
            if !isViewLoaded { let _ = view }
            
            titleLabel.text = newValue
        }
    }
    
    var alertMessage: String? {
        get { return isViewLoaded ? descriptionLabel.text : nil }
        set {
            if !isViewLoaded { let _ = view }
            
            descriptionLabel.text = newValue
        }
    }
    
    func setAction(withTitle title: String, action: (() -> Void)? = nil) {
        actionButton.setTitle(title, for: .normal)
        onAction = action
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViews()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UI_USER_INTERFACE_IDIOM() == .phone {
            return .portrait
        } else {
            return .landscape
        }
    }
    
    private func configureViews() {
        guard let stylesManager = ZAAppConnector.sharedInstance().layoutsStylesDelegate else {
            return
        }
        
        alertBackgroundImageView.setZappStyle(using: stylesManager,
                                              withAsset: .alertBackground,
                                              stretchableImage: true)
        titleLabel.setZappStyle(using: stylesManager, style: .alertTitle)
        descriptionLabel.setZappStyle(using: stylesManager, style: .alertDescription)
        
        actionButton.setZappStyle(using: stylesManager,
                                  backgroundAsset: .confirmButtonBackground,
                                  title: manager?.localizedString(for: .alertOKAction, defaultString: NSLocalizedString("OK", comment: "OK")),
                                  style: .confirmButton)
    }
    
    @objc @IBAction private func actionButtonPressed() {
        onAction?()
        if let vc = presentingViewController {
            vc.dismiss(animated: true, completion: nil)
        }
        if let currentViewController = ZAAppConnector.sharedInstance().navigationDelegate.currentViewController() as? ZPUIBuilderScreenProtocol {
            currentViewController.reloadScreen()
        }
    }
    
    class func alert(from storyboard: UIStoryboard) throws -> CleengLoginAlertController {
        guard let alert = storyboard.instantiateViewController(withIdentifier: "Alert") as? CleengLoginAlertController else {
            throw NSError.init(domain: "CleengLogin", code: -100, userInfo: [NSLocalizedDescriptionKey : "Can't create alert view controller"])
        }
        
        return alert
    }
    
    func presentMe(from vc: UIViewController) {
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
        vc.present(self, animated: true, completion: nil)
    }
    
    //MARK: - UIViewControllerTransitioningDelegate
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AlertPresentationAnimatedTransitioning()
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return AlertDismissAnimatedTransitioning()
    }
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return AlertPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

//MARK: - AlertPresentationController
private class AlertPresentationController : UIPresentationController {
    let dimmingView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0, alpha: 0.25)
        v.isUserInteractionEnabled = false
        return v
    }()
    
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else {
            return .zero
        }
        
        let maximumSize = CGSize(width: min(containerView.bounds.width - 60, 400), height: min(max(containerView.bounds.height - 200, 400), 500))
        
        guard let toView = presentedView else {
            return CGRect(x: (containerView.width - maximumSize.width) * 0.5, y: (containerView.height - maximumSize.height) * 0.5, width: maximumSize.width, height: maximumSize.height)
        }
        
        var bestSize = toView.systemLayoutSizeFitting(maximumSize, withHorizontalFittingPriority: .fittingSizeLevel, verticalFittingPriority: .fittingSizeLevel)
        bestSize.width = min(ceil(bestSize.width) + 10, maximumSize.width)
        bestSize.height = min(ceil(bestSize.height) + 10, maximumSize.height)
        
        return CGRect(x: (containerView.width - bestSize.width) * 0.5, y: (containerView.height - bestSize.height) * 0.5, width: bestSize.width, height: bestSize.height)
    }
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        dimmingView.frame = containerView?.bounds ?? .zero
    }
    
    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        dimmingView.frame = containerView?.bounds ?? .zero
        
        containerView?.addSubview(dimmingView)
        
        if let transitionCoordinator = self.presentingViewController.transitionCoordinator {
            dimmingView.alpha = 0
            transitionCoordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 1
            }, completion: nil)
        }
    }
    
    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        
        if let transitionCoordinator = self.presentingViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { _ in
                self.dimmingView.alpha = 0
            }, completion: nil)
        }
    }
}

private class AlertPresentationAnimatedTransitioning : NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: transitionContext)
        let toView = transitionContext.view(forKey: .to)!
        let containerView = transitionContext.containerView
        
        toView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        toView.alpha = 0.4
        containerView.addSubview(toView)
        
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .layoutSubviews], animations: {
            toView.transform = .identity
            toView.alpha = 1
        }) { finished in
            transitionContext.completeTransition(finished)
        }
    }
}

private class AlertDismissAnimatedTransitioning : NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let duration = transitionDuration(using: transitionContext)
        let fromView = transitionContext.view(forKey: .from)!
        assert(fromView.superview != nil, "WTF?!")
        if fromView.superview == nil {
            transitionContext.completeTransition(true)
        }
        
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5, options: [.beginFromCurrentState, .layoutSubviews], animations: {
            fromView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            fromView.alpha = 0
        }) { finished in
            transitionContext.completeTransition(finished)
        }
    }
}
