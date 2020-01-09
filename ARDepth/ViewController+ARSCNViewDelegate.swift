/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ARSCNViewDelegate interactions for `ViewController`.
*/

import ARKit

extension ViewController: ARSCNViewDelegate, ARSessionDelegate {
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        let isAnyObjectInView = virtualObjectLoader.loadedObjects.contains { object in
            return sceneView.isNode(object, insideFrustumOf: sceneView.pointOfView!)
        }
        
        DispatchQueue.main.async {
            self.updateFocusSquare(isObjectVisible: isAnyObjectInView)
            
            // If the object selection menu is open, update availability of items
            if self.objectsViewController?.viewIfLoaded?.window != nil {
                self.objectsViewController?.updateObjectAvailability()
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard anchor is ARPlaneAnchor else { return }
        DispatchQueue.main.async {
            self.statusViewController.cancelScheduledMessage(for: .planeEstimation)
            self.statusViewController.showMessage("Surface detected")
            
            if self.virtualObjectLoader.loadedObjects.isEmpty {
                self.statusViewController.scheduleMessage("Tap to ping the surface", inSeconds: 7.5, messageType: .contentPlacement)
            }
        }
        
        // Add mesh visualization
//        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
//        let planeGeometry = ARSCNPlaneGeometry(device: MTLCreateSystemDefaultDevice()!)!
//        planeGeometry.update(from: planeAnchor.geometry)
//
//        // Add material to geometry
//        let material = SCNMaterial()
//        material.diffuse.contents = UIColor.blue.withAlphaComponent(0.7)
//        material.lightingModel = .physicallyBased
//        planeGeometry.materials = [material]
//
//        // Create a SCNNode from geometry
//        let planeNode = SCNNode(geometry: planeGeometry)
//
//        // Add the newly created plane node as a child of the node created for the ARAnchor
//        node.addChildNode(planeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        updateQueue.async {
            if let objectAtAnchor = self.virtualObjectLoader.loadedObjects.first(where: { $0.anchor == anchor }) {
                objectAtAnchor.simdPosition = anchor.transform.translation
                objectAtAnchor.anchor = anchor
            }
        }
        
        //        // Cast ARAnchor as ARPlaneAnchor, get the child node of the anchor, and cast that node's geometry as an ARSCNPlaneGeometry
//        guard
//        let planeAnchor = anchor as? ARPlaneAnchor,
//        let planeNode = node.childNodes.first,
//        let planeGeometry = planeNode.geometry as? ARSCNPlaneGeometry
//        else { return }
//
//        planeGeometry.update(from: planeAnchor.geometry)
    }
    
    /// - Tag: ShowVirtualContent
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        statusViewController.showTrackingQualityInfo(for: camera.trackingState, autoHide: true)
        switch camera.trackingState {
        case .notAvailable, .limited:
            statusViewController.escalateFeedback(for: camera.trackingState, inSeconds: 3.0)
        case .normal:
            statusViewController.cancelScheduledMessage(for: .trackingStateEscalation)
            showVirtualContent()
        }
    }

    func showVirtualContent() {
        virtualObjectLoader.loadedObjects.forEach { $0.isHidden = false }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Hide content before going into the background.
        hideVirtualContent()
    }
    
    /// - Tag: HideVirtualContent
    func hideVirtualContent() {
        virtualObjectLoader.loadedObjects.forEach { $0.isHidden = true }
    }

    /*
     Allow the session to attempt to resume after an interruption.
     This process may not succeed, so the app must be prepared
     to reset the session if the relocalizing status continues
     for a long time -- see `escalateFeedback` in `StatusViewController`.
     */
    /// - Tag: Relocalization
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
}
