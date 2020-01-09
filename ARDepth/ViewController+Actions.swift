/*
See LICENSE folder for this sample’s licensing information.

Abstract:
UI Actions for the main view controller.
*/

import UIKit
import SceneKit
import AVFoundation

// Sonar pings
let sonarOut: SystemSoundID = 1057
let sonarIn: SystemSoundID = 1103

extension ViewController: UIGestureRecognizerDelegate {
    
    enum SegueIdentifier: String {
        case showObjects
    }
    
    // MARK: - Interface Actions
    
    /// Displays the `VirtualObjectSelectionViewController` from the `addObjectButton` or in response to a tap gesture in the `sceneView`.
    @IBAction func showVirtualObjectSelectionViewController() {
        // Ensure adding objects is an available action and we are not loading another object (to avoid concurrent modifications of the scene).
//        guard !addObjectButton.isHidden && !virtualObjectLoader.isLoading else { return }
        
        statusViewController.cancelScheduledMessage(for: .contentPlacement)
        // performSegue(withIdentifier: SegueIdentifier.reportDepth.rawValue, sender: addObjectButton)
        
        reportDepth()
    }
    
    @IBAction func beginContinuousDepthReporting(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            self.becomeFirstResponder()
            self.continuousReportingActive = true
        } else if gestureRecognizer.state == .ended {
            self.continuousReportingActive = false
        }
    }
    
    /// Determines if the tap gesture for presenting the `VirtualObjectSelectionViewController` should be used.
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        return virtualObjectLoader.loadedObjects.isEmpty
    }
    
    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        return true
    }
    
    /// - Tag: restartExperience
    func restartExperience() {
        guard isRestartAvailable, !virtualObjectLoader.isLoading else { return }
        isRestartAvailable = false

        statusViewController.cancelAllScheduledMessages()

        virtualObjectLoader.removeAllVirtualObjects()
        addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
        addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])

        resetTracking()

        // Disable restart for a while in order to give the session time to restart.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.isRestartAvailable = true
            self.upperControlsView.isHidden = false
        }
    }
    
    func reportDepth() {
        guard isDepthReportAvailable, !virtualObjectLoader.isLoading else { return }
        
        // Disable new depth report until last is completed to prevent button mashing behavior
        isDepthReportAvailable = false

        statusViewController.cancelAllScheduledMessages()
        
        // Report outbound ping audio/haptic
        self.sonarHapticOut.impactOccurred()
        AudioServicesPlaySystemSound (sonarOut)
        
        // Prepare for sonar in
        self.sonarHapticIn.prepare()
        
        // Delay depth by distance for sonar effect
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(self.focusSquare.distanceFromCamera) / 4) {
            
            // Report ping audio/haptic
            self.sonarHapticIn.impactOccurred()
            AudioServicesPlaySystemSound (sonarIn)
            
            // Prepare for next sonar out
            self.sonarHapticOut.prepare()
            
            // Re-enable depth report
            self.isDepthReportAvailable = true
            self.upperControlsView.isHidden = false
        }
    }
}

extension ViewController: UIPopoverPresentationControllerDelegate {
    
    // MARK: - UIPopoverPresentationControllerDelegate

    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // All menus should be popovers (even on iPhone).
        if let popoverController = segue.destination.popoverPresentationController, let button = sender as? UIButton {
            popoverController.delegate = self
            popoverController.sourceView = button
            popoverController.sourceRect = button.bounds
        }
        
        guard let identifier = segue.identifier,
            let segueIdentifer = SegueIdentifier(rawValue: identifier) else { return }
        
        switch segueIdentifer {
        case .showObjects:
            let objectsViewController = segue.destination as! VirtualObjectSelectionViewController
                     
            objectsViewController.virtualObjects = VirtualObject.availableObjects
            objectsViewController.delegate = self
            objectsViewController.sceneView = sceneView
            self.objectsViewController = objectsViewController

            // Set all rows of currently placed objects to selected.
            for object in virtualObjectLoader.loadedObjects {
                guard let index = VirtualObject.availableObjects.firstIndex(of: object) else { continue }
                objectsViewController.selectedVirtualObjectRows.insert(index)
            }
        }
    }
    
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        objectsViewController = nil
    }
}
