//
//  TransactionsViewModel.swift
//  Wallet
//
//  Created by Nathan Clark on 10/30/21.
//

import Foundation
import SafariWalletCore
import MEWwalletKit

final class TransactionsListViewModel: ObservableObject {
    
    enum State: Equatable {
        case loading
        case fetched(txs: [TransactionGroup])
        case error(message: String)
    }
    // TODO: show error
    @Published var viewModels: [TransactionViewModel] = []
    @Published var state: State = .loading
    
    private var transactions2: [TransactionActivity] = []
    private var transactions: [TransactionGroup] = []
    // TODO: Implement contract caching
    private var contracts: [String: Contract] = [:]
    
    private let chain: String
    private let address: String
    private let currency: String
    private let symbol: String
    
    private var isFetching = false
    
    private let txService: TransactionFetchable
    private let contractService: ContractFetchable
    
    init(chain: String,
         address: String,
         currency: String,
         symbol: String,
         txService: TransactionFetchable = TransactionService(),
         contractService: ContractFetchable = ContractService()
    ) {
        self.chain = chain
        self.address = address
        self.currency = currency
        self.symbol = symbol
        self.txService = txService
        self.contractService = contractService
    }
    
    func fetchTransactions() {
        guard let address = Address(ethereumAddress: address) else { return }
        isFetching = true
        Task {
            do {
                let fetchedTransactions = try await self.txService.fetchTransactions(network: .ethereum, address: address)
                //                    await fetchContracts(fromTxs: fetchedTransactions)
                //                    let txs = fetchedTransactions.map { tx -> TransactionGroup in
                //                        var tx = tx
                //                        let contract = contracts[tx.toAddress]
                //                        if let nameTag = contract?.nameTag, !nameTag.isEmpty {
                //                            tx.contractName = nameTag
                //                        } else if let contractName = contract?.name, !contractName.isEmpty {
                //                            tx.contractName = contractName
                //                        } else {
                //                            tx.contractName = tx.toAddress
                //                        }
                //                        return tx
                //                    }
                //                    self.transactions.append(contentsOf: txs)
                
                
                let viewModels = fetchedTransactions.map(TransactionViewModel.init)
                self.viewModels.append(contentsOf: viewModels)
                
                state = .fetched(txs: self.transactions)
                isFetching = false
            } catch let error {
                //TODO: Error handling / Define error cases and appropriate error messages
                state = .error(message: error.localizedDescription)
            }
        }
    }
    
    func fetchTransactionsIfNeeded(currentTransaction transaction: TransactionGroup) {
        guard canLoadNextPage(atTransaction: transaction) else { return }
        fetchTransactions()
    }
    
    private func canLoadNextPage(atTransaction transaction: TransactionGroup) -> Bool {
        guard let index: Int = transactions.firstIndex(of: transaction) else { return false }
        let reachedThreshold = Double(index) / Double(transactions.count) > 0.7
        return !isFetching && reachedThreshold
    }
    
    @MainActor
    private func fetchContracts(fromTxs txs: [TransactionGroup]) async {
        var contracts = [Contract]()
        await withTaskGroup(of: Contract?.self) { [weak self] group in
            guard let self = self else { return }
            for tx in txs {
                group.addTask {
                    guard let contractAddress = tx.transactions.first?.to,
                          self.contracts[tx.toAddress] == nil else { return nil }
                    return try? await self.contractService.fetchContractDetails(forAddress: contractAddress)
                }
                for await contract in group {
                    guard let contract = contract else { return }
                    contracts.append(contract)
                }
            }
        }
        for contract in contracts {
            self.contracts[contract.address] = contract
        }
    }
}

enum TransactionFilter: Int {
    case all
    case sent
    case received
    case interactions
    case failed
}