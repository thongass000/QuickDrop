//
//  MdnsTester.swift
//  QuickDrop
//
//  Created by Leon Böttger on 14.05.25.
//

import Foundation

class MDNSSelfTest: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    private var service: NetService?
    private var browser: NetServiceBrowser?
    private var didFindOwnService = false
    private var completionHandler: ((Bool) -> Void)?

    func testBonjourAvailability(timeout: TimeInterval = 5.0, completion: @escaping (Bool) -> Void) {
        self.completionHandler = completion

        // Step 1: Start advertising a Bonjour service
        let serviceName = "MDNS-Test-\(UUID().uuidString.prefix(6))"
        service = NetService(domain: "local.", type: "_mdnstest._tcp.", name: serviceName, port: 12345)
        service?.delegate = self
        service?.publish()

        // Step 2: Start browsing for it
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: "_mdnstest._tcp.", inDomain: "local.")

        // Step 3: Timeout if nothing is found
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            self.stop()
            self.completionHandler?(self.didFindOwnService)
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if service.name == self.service?.name {
            didFindOwnService = true
            stop()
            completionHandler?(true)
            completionHandler = nil
        }
    }

    func stop() {
        service?.stop()
        browser?.stop()
        service = nil
        browser = nil
    }
}
