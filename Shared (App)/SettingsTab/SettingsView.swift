//
//  SettingsView.swift
//  Wallet
//
//  Created by Ronald Mannak on 11/5/21.
//

import SwiftUI
import MEWwalletKit

struct SettingsView: View {
    
    private let manager = WalletManager()
    
    private let networks: [String] = ["Mainnet", "Ropsten"]
    @State private var selectedNetworkIndex = 0
    
    @State private var wallets: [String] = []
    @State private var selectedWalletIndex = 0
    
    @State private var addresses: [String] = []
    @State private var selectedAddressIndex = 0
        
    var body: some View {

        Form {
            
            // MARK: - Wallet selection
            Section(header: Text("Wallet")) {
                Picker(selection: $selectedWalletIndex, label: Text("")) {
                    ForEach(0 ..< wallets.count, id: \.self) { i in
                        Text(wallets[i]).tag(i)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
                .onChange(of: selectedWalletIndex) { tag in
                    print(tag)
                    // TODO: wallet
                }
            }
            .task {
                guard let defaultWallet = manager.defaultWallet, let wallets = try? manager.listWalletFiles() else { return }
                self.wallets = wallets
                self.selectedWalletIndex = wallets.firstIndex(of: defaultWallet) ?? 0
            }
            
            // MARK: - Accounts selection
            Section(header: Text("Selected account in wallet")) {
                Picker(selection: $selectedAddressIndex, label: Text("")) {
                    ForEach(0..<addresses.count, id: \.self) { i in
                        Text(addresses[i]).tag(i)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
                .onChange(of: selectedAddressIndex) { tag in
                    manager.defaultAddress = self.addresses[tag]
                }
            }
            .task {
                guard let defaultWallet = manager.defaultWallet, let addresses = try? await manager.loadAddresses(name: defaultWallet), let defaultAddress = manager.defaultAddress else { return }
                self.addresses = addresses
                self.selectedAddressIndex = addresses.firstIndex(of: defaultAddress) ?? 0
             }

            // MARK: - Network selection
            Section(header: Text("Network")) {
                Picker(selection: $selectedNetworkIndex, label: Text("")) {
                    ForEach(networks.indices) { i in
                        Text(networks[i]).tag(i)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
                .onChange(of: selectedNetworkIndex) { tag in
                    if tag == 1 {
                        manager.defaultNetwork = .ropsten
                    } else {
                        manager.defaultNetwork = .ethereum
                    }
                }
                .onAppear {
                    if case .ropsten = manager.defaultNetwork  {
                        selectedNetworkIndex = 1
                    } else {
                        selectedNetworkIndex = 0
                    }
                    
                }
            }
        }
    }
    
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
