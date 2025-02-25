//
//  SafariWebExtensionHandler.swift
//  Shared (Extension)
//
//  Created by Nathan Clark on 9/30/21.
//

import SafariServices
import SafariWalletCore
import os.log

let SFExtensionMessageKey = "message"
let SFSFExtensionResponseErrorKey = "error"
 
class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    
    let walletManager = WalletManager()
    let logger = Logger()
    
    func beginRequest(with context: NSExtensionContext) {
        
        // TODO: can we fire a timer here that keeps checks on changes (e.g. account)?
        
        Task {
            let response = NSExtensionItem()
            defer { context.completeRequest(returningItems: [response], completionHandler: nil) }

            // Sanity check
            let item = context.inputItems[0] as! NSExtensionItem
            guard let message = item.userInfo?[SFExtensionMessageKey] else {
                response.userInfo = errorResponse(error: "No message key in message.\(String(describing: item.userInfo))")
                logger.critical("Safari-wallet SafariWebExtensionHandler: No message key in message")
                return
            }
                        
            logger.critical("Safari-wallet SafariWebExtensionHandler: Received message from browser.runtime.sendNativeMessage: \(String(describing: message))")
            
            // Parse message
            do {
                let returnValue = try await handle(message: message)
                response.userInfo = [SFExtensionMessageKey: returnValue]
                logger.critical("Safari-wallet SafariWebExtensionHandler received \(String(describing: returnValue))")
            } catch WalletError.noMethod {
                response.userInfo = errorResponse(error: "No method found")
            } catch WalletCoreError.noParameters {
                response.userInfo = errorResponse(error: "Missing paramaters")
            } catch WalletError.invalidInput {
                response.userInfo = errorResponse(error: "Error parsing input")
            } catch WalletCoreError.noClient {
                response.userInfo = errorResponse(error: "No Client")
            } catch {
                response.userInfo = errorResponse(error: error.localizedDescription)
//                logger.critical("Safari-wallet SafariWebExtensionHandler error: \(error.localizedDescription))")
            }
        }
    }
    
    fileprivate func errorResponse(error: String) -> [String: Any] {
        return [SFExtensionMessageKey: [SFSFExtensionResponseErrorKey: error]]
    }

    // MARK: - Web3 Message handling

    func handle(message: Any) async throws -> Any {
        let providerAPI = ProviderAPI(delegate: walletManager)
        
        // Parse method and params
        if let message = message as? String {
            return try await providerAPI.parseMessage(method: message, params: nil)
        } else if let message = message as? [String: Any] {
            guard let method = message["method"] as? String else { throw WalletError.noMethod }
            let params = message["params"]
            return try await providerAPI.parseMessage(method: method, params: params)
        } else {
            throw WalletError.invalidInput
        }
    }
}
