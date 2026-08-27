//
//  ViewController.swift
//  Session-Manager
//
//  Created by dhruv@tor.us on 04/12/2023.
//  Copyright (c) 2023 dhruv@tor.us. All rights reserved.
//

import UIKit
import SessionManager
import curveSecp256k1

class ViewController: UIViewController {
    struct SFAModel: Codable {
        let publicKey: String
        let privateKey: String
    }
    
    var session: StorageManager<SFAModel>!

    private func generatePrivateandPublicKey() throws -> (privKey: String, pubKey: String) {
        let privKeyData = curveSecp256k1.SecretKey()
        let publicKey = try privKeyData.toPublic()
        let serialized = try publicKey.serialize(compressed: false)
        return (privKey: try privKeyData.serialize(), pubKey: serialized)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Task {
            let sessionId = try StorageManager<SFAModel>.generateRandomSessionKey()
            session = StorageManager<SFAModel>(
                sessionServerBaseUrl: SESSION_SERVER_API_URL,
                sessionId: sessionId
            )
            let (privKey, pubKey) = try generatePrivateandPublicKey()
            let sfa = SFAModel(publicKey: pubKey, privateKey: privKey)
            let created = try await session.createSession(data: sfa)
            StorageManager<SFAModel>.saveSessionIdToStorage(created)
            let auth = try await session.authorizeSession()
            print(created)
            print(auth)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
