//
//  ARViewController.swift
//  PlaneDetection
//
//  Created by Jinwoo Kim on 5/27/24.
//

import UIKit
import ARKit
import RealityKit

@MainActor
final class ARViewController: UIViewController {
    private var arView: ARView! { view as? ARView }
    
    override func loadView() {
        let arView: ARView = .init(frame: .null, cameraMode: .ar, automaticallyConfigureSession: false)
        
        let configuration: ARWorldTrackingConfiguration = .init()
        configuration.planeDetection = [.horizontal, .vertical]
        
        let session: ARSession = arView.session
        session.delegate = self
        session.run(configuration)
        
        view = arView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension ARViewController: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for case let planeAnchor as ARPlaneAnchor in anchors {
            let anchorEntity: AnchorEntity = .init(anchor: planeAnchor)
            
            let mesh: MeshResource = .generateSphere(radius: 1E-2)
//            let mesh_2: MeshResource = .generate(from: planeAnchor.geometry.vertices)
//            let mesh_2: MeshResource = .generatePlane(width: planeAnchor.planeExtent.width, height: planeAnchor.planeExtent.height)
            
            let text: String
            switch planeAnchor.classification {
            case .ceiling:
                text = "Ceiling"
            case .wall:
                text = "Wall"
            case .floor:
                text = "Table"
            case .table:
                text = "Table"
            case .seat:
                text = "Seat"
            case .window:
                text = "Window"
            case .door:
                text = "Door"
            default:
                text = "Unknown"
            }
            
            let position: SIMD3<Float> = anchorEntity.position
            let testMesh: MeshResource = .generateText(text, containerFrame: .init(origin: .zero, size: .init(width: 100.0, height: 100.0)))
            
            let modelEntity: ModelEntity = .init(
                mesh: mesh,
                materials: [
                    SimpleMaterial(color: .white, isMetallic: true)
                ]
            )
            
            modelEntity.position = planeAnchor.center
            modelEntity.transform = .init(
                scale: .init(x: 0.01, y: 0.01, z: 0.01),
                rotation: .init(angle: -.pi / 2.0, axis: .init(x: 1.0, y: .zero, z: .zero)),
                translation: .zero
            )
            
            anchorEntity.addChild(modelEntity)
            
            arView.scene.addAnchor(anchorEntity)
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let existingAnchorEntities: [AnchorEntity] = arView
            .scene
            .anchors
            .compactMap { $0 as? AnchorEntity }
        
        guard !existingAnchorEntities.isEmpty else { return }
        
        for case let planeAnchor as ARPlaneAnchor in anchors {
            guard let anchorEntity: AnchorEntity = existingAnchorEntities
                .first(where: { $0.anchoring.target == .anchor(identifier: planeAnchor.identifier) })
            else {
                continue
            }
            
            let text: String
            switch planeAnchor.classification {
            case .ceiling:
                text = "Ceiling"
            case .wall:
                text = "Wall"
            case .floor:
                text = "Table"
            case .table:
                text = "Table"
            case .seat:
                text = "Seat"
            case .window:
                text = "Window"
            case .door:
                text = "Door"
            default:
                text = "Unknown"
            }
            print(text)
            
            for case let modelEntity as ModelEntity in anchorEntity.children {
                modelEntity.model?.mesh = .generateText(text)
                modelEntity.position = planeAnchor.center
            }
        }
    }
}
