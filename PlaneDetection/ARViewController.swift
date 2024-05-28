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
            
            //
            
            let geometryMesh: MeshResource = planeAnchor.geometry.meshResource!
            
            let geometryEntity: ModelEntity = .init(
                mesh: geometryMesh,
                materials: [
                    SimpleMaterial(color: .white.withAlphaComponent(0.5), isMetallic: false)
                ]
            )
            
            geometryEntity.name = "Geometry"
            
            anchorEntity.addChild(geometryEntity, preservingWorldTransform: true)
            
            //
            
            let textMesh: MeshResource = .generateText(planeAnchor.classification.text)
            
            let textEntity: ModelEntity = .init(
                mesh: textMesh, 
                materials: [
                    SimpleMaterial(color: .systemPink, isMetallic: false)
                ]
            )
            
            textEntity.transform = .init(
                scale: .init(x: 0.01, y: 0.01, z: 0.01),
                rotation: .init(angle: -.pi / 2.0, axis: .init(x: 1.0, y: .zero, z: .zero)),
                translation: .zero
            )
            
            textEntity.position = planeAnchor.center
            
            textEntity.name = "Text"
            
            anchorEntity.addChild(textEntity)
            
            //
            
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
            
            for case let modelEntity as ModelEntity in anchorEntity.children {
                let name: String = modelEntity.name
                
                if name == "Geometry" {
                    if let meshResource: MeshResource = planeAnchor.geometry.meshResource {
                        modelEntity.model?.mesh = meshResource
                    } else {
                        modelEntity.model = nil
                    }
                } else if name == "Text" {
                    modelEntity.model?.mesh = .generateText(planeAnchor.classification.text)
                    modelEntity.position = planeAnchor.center
                }
            }
        }
    }
}

extension ARPlaneAnchor.Classification {
    fileprivate var text: String {
        switch self {
        case .ceiling:
            return "Ceiling"
        case .wall:
            return "Wall"
        case .floor:
            return "Table"
        case .table:
            return "Table"
        case .seat:
            return "Seat"
        case .window:
            return "Window"
        case .door:
            return "Door"
        default:
            return "Unknown"
        }
    }
}

extension ARPlaneGeometry {
    fileprivate var meshResource: MeshResource? {
        var meshDescriptor: MeshDescriptor = .init()
        meshDescriptor.positions = .init(boundaryVertices)
        meshDescriptor.primitives = .triangles(triangleIndices.map { UInt32($0) })
        
        return try? .generate(from: [meshDescriptor])
    }
}
