//
//  ViewController.swift
//  Mixed Reality
//
//  Created by Pedro Cardoso on 23/01/2019.
//  Copyright © 2019 Mokriya LLC. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import VideoToolbox
import AVFoundation


class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var planeNodes: [SCNNode] = []
    var addPlane = true

    override func viewDidLoad() {
        super.viewDidLoad()

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action:
            #selector(ViewController.viewTapped(withGestureRecognizer:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)

        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene() // SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        sceneView.debugOptions = [.showFeaturePoints ]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard addPlane else { return }
        
        // 1
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        // 2
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        let plane = SCNPlane(width: width, height: height)

        // 3
        plane.materials.first?.diffuse.contents = UIColor.blue.withAlphaComponent(0.3)

        // 4
        let planeNode = SCNNode(geometry: plane)

        // 5
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x,y,z)
        planeNode.eulerAngles.x = -.pi / 2

        // 6
        node.addChildNode(planeNode)
        
        planeNodes.append(planeNode)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }

        // 2
        let width = CGFloat(planeAnchor.extent.x)
        let height = CGFloat(planeAnchor.extent.z)
        plane.width = width
        plane.height = height

        // 3
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)
        planeNode.position = SCNVector3(x, y, z)
    }

    @objc func viewTapped(withGestureRecognizer recognizer: UIGestureRecognizer) {
        let tapLocation = recognizer.location(in: sceneView)
        let hitTestResults = sceneView.hitTest(tapLocation, types: .existingPlaneUsingExtent)
        guard let res = hitTestResults.first,
            let anchor = res.anchor else { return }

        print("plane distance: \(res.distance)")
        
        guard let pic = UIImage(pixelBuffer: sceneView.session.currentFrame!.capturedImage)?.fixedOrientation() else { return }
        
        let insideRect = AVMakeRect(aspectRatio: sceneView.bounds.size, insideRect: CGRect(origin: .zero, size: pic.size))
        let pic2 = pic.cropped(boundingBox: insideRect)
        
        let size = res.distance / 2
       
        let planeGeometry = SCNPlane(width: size, height: size)
        planeGeometry.firstMaterial?.diffuse.contents = UIColor.red.withAlphaComponent(0.9)
        let planeNode = SCNNode(geometry: planeGeometry)

        planeNode.simdTransform = anchor.transform
        planeNode.eulerAngles = SCNVector3Make(planeNode.eulerAngles.x - (Float.pi / 2), planeNode.eulerAngles.y, planeNode.eulerAngles.z)
        planeNode.position = res.worldTransform.position(offset: SCNVector3(0, 0, 0.01))
        
      
        sceneView.scene.rootNode.addChildNode(planeNode)
        
        //        guard let shipScene = SCNScene(named: "ship.scn"),
        //            let shipNode = shipScene.rootNode.childNode(withName: "ship", recursively: false)
        //            else { return }
        //
        //
        //        shipNode.position = SCNVector3(x,y,z)
        //        sceneView.scene.rootNode.addChildNode(shipNode)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2) { [weak planeNode, weak sceneView] in
            
            guard let planeNode = planeNode, let sceneView = sceneView else { return }
            let bbox = planeNode.presentation.boundingBox
            
            // world coordinates
            let v1w =  planeNode.convertPosition(bbox.min, to: sceneView.scene.rootNode)
            let v2w =  planeNode.convertPosition(bbox.max, to: sceneView.scene.rootNode)
            
//            v1w.z = 0
//            v2w.z = 0
            
            //projected coordinates
            let v1p = sceneView.projectPoint(v1w)
            let v2p = sceneView.projectPoint(v2w)
            
            //frame rectangle
            let rect = CGRect(x: CGFloat(v1p.x), y: CGFloat(v2p.y), width: max(10, CGFloat(v2p.x - v1p.x)), height: max(10, CGFloat(v1p.y - v2p.y)))
            
//            let rectView = UIView(frame: rect)
//            rectView.alpha = 0.3
//            rectView.backgroundColor = UIColor.purple
//            sceneView.addSubview(rectView)
            
            print("v1 \(bbox.min), v2\(bbox.max)")
            print("v1w \(v1w), v2w \(v2w)")
            print("v1p \(v1p), v2p \(v2p)")
            print("rect\(rect)")
            
            let sel = pic2!.withGrayscale.cropped(boundingBox: rect.scaled(by: pic2!.size.width / sceneView.bounds.width))
           
            planeGeometry.firstMaterial?.diffuse.contents = sel
        }
        
        addPlane = false
        planeNodes.forEach {
            $0.removeFromParentNode()
        }
    }
    
    func updatePositionAndOrientationOf(_ node: SCNNode, withPosition position: SCNVector3, relativeTo referenceNode: SCNNode) {
        let referenceNodeTransform = matrix_float4x4(referenceNode.transform)
        
        // Setup a translation matrix with the desired position
        var translationMatrix = matrix_identity_float4x4
        translationMatrix.columns.3.x = position.x
        translationMatrix.columns.3.y = position.y
        translationMatrix.columns.3.z = position.z
        
        // Combine the configured translation matrix with the referenceNode's transform to get the desired position AND orientation
        let updatedTransform = matrix_multiply(referenceNodeTransform, translationMatrix)
        node.transform = SCNMatrix4(updatedTransform)
    }
    

}
