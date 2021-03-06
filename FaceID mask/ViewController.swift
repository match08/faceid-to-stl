import UIKit
import SceneKit
import ARKit

protocol VirtualFaceContent {
    func update(withFaceAnchor: ARFaceAnchor)
}

typealias VirtualFaceNode = VirtualFaceContent & SCNNode

class Mask: SCNNode, VirtualFaceContent {

    init(geometry: ARSCNFaceGeometry) {
        let material = geometry.firstMaterial!

        material.diffuse.contents = UIColor.lightGray
        material.lightingModel = .physicallyBased

        super.init()
        self.geometry = geometry
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }

    func update(withFaceAnchor anchor: ARFaceAnchor) {
        let faceGeometry = geometry as! ARSCNFaceGeometry
        faceGeometry.update(from: anchor.geometry)
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    private var isPresentingShareSheet = false
    private var mask: Mask?
    private var lastFaceAnchor: ARFaceAnchor?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        startSession()

        let button = UIButton(type: .custom)
        button.setTitle("Capture", for: .normal)
        button.tintColor = .black
        button.titleLabel?.textColor = .black
        button.backgroundColor = .lightGray
        button.addTarget(self, action: #selector(capture), for: .touchUpInside)
        button.layer.cornerRadius = 12
        view.addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        let constraints: [NSLayoutConstraint] = [
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 55)
        ]
        view.addConstraints(constraints)
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let device = sceneView.device!
        let maskGeometry = ARSCNFaceGeometry(device: device)!
        mask = Mask(geometry: maskGeometry)

        node.addChildNode(mask!)

    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        mask?.update(withFaceAnchor: faceAnchor)

        if let faceAnchor = anchor as? ARFaceAnchor {
            lastFaceAnchor = faceAnchor
        }
    }

    private func startSession() {
        sceneView.scene.rootNode.childNodes.forEach {
            $0.removeFromParentNode()
        }

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    @objc
    private func capture() {
        guard let faceAnchor = lastFaceAnchor else {
            return
        }
        
        let data = createSTL(from: faceAnchor)
        let url = generateURL(for: data)
        presentShareSheet(with: url)
    }

    private func createSTL(from faceAnchor: ARFaceAnchor) -> Data {

        let mapped = faceAnchor.geometry.triangleIndices.map { i in
            return faceAnchor.geometry.vertices[Int(i)]
        }

        var out: [String] = ["solid face"]
        mapped.enumerated().forEach { i, vertex in
            if i % 3 == 0 {
                out.append("facet normal 0 0 0")
                out.append("\touter loop")
            }

            out.append("\t\tvertex \(vertex.x) \(vertex.y) \(vertex.z)")

            if i % 3 == 2 {
                out.append("\tendloop")
            }
        }

        out.append("endsolid face")

        let file = out.joined(separator: "\n")
        let data = file.data(using: .ascii)!
        return data
    }

    private func generateURL(for data: Data) -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "face.stl")
        try! data.write(to: url)
        return url
    }

    private func presentShareSheet(with url: URL) {
        self.isPresentingShareSheet = true
        DispatchQueue.main.async {
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            activityViewController.completionWithItemsHandler = { _, _, _, _ in
                 self.isPresentingShareSheet = false
            }
            self.present(activityViewController, animated: true, completion: nil)
        }
    }
}
