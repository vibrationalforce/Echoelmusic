// EchoelaModuleTests.swift
// Echoelmusic Tests
//
// Comprehensive Tests for Echoela AI Assistant and NFT Factory Modules
// Tests for: EchoelaManager, NFTFactory, ComplianceManager
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import XCTest
@testable import Echoelmusic

final class EchoelaModuleTests: XCTestCase {

    // MARK: - EchoelaManager Tests

    @MainActor
    func testEchoelaManagerSingletonExists() {
        let manager = EchoelaManager.shared
        XCTAssertNotNil(manager)
    }

    @MainActor
    func testEchoelaManagerInitialState() {
        let manager = EchoelaManager.shared
        XCTAssertEqual(manager.currentContext, .idle)
        XCTAssertFalse(manager.isProcessing)
    }

    @MainActor
    func testEchoelaContextValues() {
        XCTAssertEqual(EchoelaManager.EchoelaContext.idle.rawValue, "idle")
        XCTAssertEqual(EchoelaManager.EchoelaContext.production.rawValue, "production")
        XCTAssertEqual(EchoelaManager.EchoelaContext.performance.rawValue, "performance")
        XCTAssertEqual(EchoelaManager.EchoelaContext.minting.rawValue, "minting")
        XCTAssertEqual(EchoelaManager.EchoelaContext.meditation.rawValue, "meditation")
        XCTAssertEqual(EchoelaManager.EchoelaContext.collaboration.rawValue, "collaboration")
        XCTAssertEqual(EchoelaManager.EchoelaContext.auv3.rawValue, "auv3")
        XCTAssertEqual(EchoelaManager.EchoelaContext.watchSensing.rawValue, "watchSensing")
    }

    @MainActor
    func testEchoelaContextChange() {
        let manager = EchoelaManager.shared
        manager.setContext(.production)
        XCTAssertEqual(manager.currentContext, .production)
        manager.setContext(.meditation)
        XCTAssertEqual(manager.currentContext, .meditation)
        manager.setContext(.idle)
        XCTAssertEqual(manager.currentContext, .idle)
    }

    func testEchoelaDeepLinkGeneration() {
        // Test deep link generation
        let url = EchoelaManager.generateDeepLink(category: "meditation", action: "start")
        XCTAssertEqual(url.scheme, "echoelmusic")
        XCTAssertTrue(url.absoluteString.contains("meditation"))
        XCTAssertTrue(url.absoluteString.contains("start"))
    }

    func testEchoelaDeepLinkCategories() {
        // Test various deep link categories
        let meditationURL = EchoelaManager.generateDeepLink(category: "meditation", action: "start")
        XCTAssertNotNil(meditationURL)

        let nftURL = EchoelaManager.generateDeepLink(category: "nft", action: "mint")
        XCTAssertNotNil(nftURL)

        let watchURL = EchoelaManager.generateDeepLink(category: "watch", action: "sensing")
        XCTAssertNotNil(watchURL)
    }

    func testEchoelaMessageRole() {
        XCTAssertEqual(EchoelaManager.EchoelaMessage.Role.user.rawValue, "user")
        XCTAssertEqual(EchoelaManager.EchoelaMessage.Role.assistant.rawValue, "assistant")
        XCTAssertEqual(EchoelaManager.EchoelaMessage.Role.system.rawValue, "system")
    }

    func testEchoelaMessageCreation() {
        let message = EchoelaManager.EchoelaMessage(
            role: .user,
            content: "Test message"
        )
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.content, "Test message")
        XCTAssertNotNil(message.id)
        XCTAssertNotNil(message.timestamp)
    }

    func testEchoelaMessageWithBioContext() {
        let bioContext = EchoelaManager.EchoelaMessage.BioContext(
            heartRate: 72.0,
            hrv: 45.0,
            coherence: 0.85
        )
        let message = EchoelaManager.EchoelaMessage(
            role: .assistant,
            content: "Response with bio data",
            bioContext: bioContext
        )
        XCTAssertNotNil(message.bioContext)
        XCTAssertEqual(message.bioContext?.heartRate, 72.0)
        XCTAssertEqual(message.bioContext?.hrv, 45.0)
        XCTAssertEqual(message.bioContext?.coherence, 0.85)
    }

    // MARK: - NFTFactory Tests

    @MainActor
    func testNFTFactorySingletonExists() {
        let factory = NFTFactory.shared
        XCTAssertNotNil(factory)
    }

    @MainActor
    func testNFTFactoryInitialState() {
        let factory = NFTFactory.shared
        XCTAssertFalse(factory.isMinting)
        XCTAssertFalse(factory.isWalletConnected)
    }

    func testNFTBlockchainNetworkValues() {
        XCTAssertEqual(NFTFactory.BlockchainNetwork.ethereum.rawValue, "ethereum")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.polygon.rawValue, "polygon")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.base.rawValue, "base")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.optimism.rawValue, "optimism")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.zora.rawValue, "zora")
    }

    func testNFTBlockchainNetworkChainIds() {
        XCTAssertEqual(NFTFactory.BlockchainNetwork.ethereum.chainId, 1)
        XCTAssertEqual(NFTFactory.BlockchainNetwork.polygon.chainId, 137)
        XCTAssertEqual(NFTFactory.BlockchainNetwork.base.chainId, 8453)
        XCTAssertEqual(NFTFactory.BlockchainNetwork.optimism.chainId, 10)
        XCTAssertEqual(NFTFactory.BlockchainNetwork.zora.chainId, 7777777)
    }

    func testNFTBlockchainNetworkDisplayNames() {
        XCTAssertEqual(NFTFactory.BlockchainNetwork.ethereum.displayName, "Ethereum")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.polygon.displayName, "Polygon")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.base.displayName, "Base")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.optimism.displayName, "Optimism")
        XCTAssertEqual(NFTFactory.BlockchainNetwork.zora.displayName, "Zora")
    }

    func testNFTBlockchainNetworkExplorerURLs() {
        XCTAssertTrue(NFTFactory.BlockchainNetwork.ethereum.explorerURL.contains("etherscan"))
        XCTAssertTrue(NFTFactory.BlockchainNetwork.polygon.explorerURL.contains("polygonscan"))
        XCTAssertTrue(NFTFactory.BlockchainNetwork.base.explorerURL.contains("basescan"))
        XCTAssertTrue(NFTFactory.BlockchainNetwork.optimism.explorerURL.contains("optimistic"))
        XCTAssertTrue(NFTFactory.BlockchainNetwork.zora.explorerURL.contains("zora"))
    }

    func testNFTMintingStateValues() {
        XCTAssertEqual(NFTFactory.MintingState.idle.rawValue, "idle")
        XCTAssertEqual(NFTFactory.MintingState.preparing.rawValue, "preparing")
        XCTAssertEqual(NFTFactory.MintingState.uploadingContent.rawValue, "uploadingContent")
        XCTAssertEqual(NFTFactory.MintingState.creatingMetadata.rawValue, "creatingMetadata")
        XCTAssertEqual(NFTFactory.MintingState.signingTransaction.rawValue, "signingTransaction")
        XCTAssertEqual(NFTFactory.MintingState.minting.rawValue, "minting")
        XCTAssertEqual(NFTFactory.MintingState.confirming.rawValue, "confirming")
        XCTAssertEqual(NFTFactory.MintingState.complete.rawValue, "complete")
        XCTAssertEqual(NFTFactory.MintingState.failed.rawValue, "failed")
    }

    func testNFTMetadataCreation() {
        let metadata = NFTFactory.NFTMetadata(
            name: "Test NFT",
            description: "A test NFT for unit testing",
            artist: "Test Artist",
            createdDate: Date(),
            network: .polygon
        )
        XCTAssertEqual(metadata.name, "Test NFT")
        XCTAssertEqual(metadata.description, "A test NFT for unit testing")
        XCTAssertEqual(metadata.artist, "Test Artist")
        XCTAssertEqual(metadata.network, .polygon)
    }

    func testNFTMetadataWithBioSnapshot() {
        let bioSnapshot = NFTFactory.NFTMetadata.BioSnapshot(
            heartRateAvg: 68.5,
            hrvAvg: 52.3,
            coherenceAvg: 0.78,
            peakCoherence: 0.92,
            duration: 300.0
        )
        let metadata = NFTFactory.NFTMetadata(
            name: "Bio-Reactive NFT",
            description: "NFT with biometric data",
            artist: "Bio Artist",
            createdDate: Date(),
            network: .ethereum,
            bioSnapshot: bioSnapshot
        )
        XCTAssertNotNil(metadata.bioSnapshot)
        XCTAssertEqual(metadata.bioSnapshot?.heartRateAvg, 68.5)
        XCTAssertEqual(metadata.bioSnapshot?.hrvAvg, 52.3)
        XCTAssertEqual(metadata.bioSnapshot?.coherenceAvg, 0.78)
        XCTAssertEqual(metadata.bioSnapshot?.peakCoherence, 0.92)
        XCTAssertEqual(metadata.bioSnapshot?.duration, 300.0)
    }

    func testNFTTokenStandardValues() {
        XCTAssertEqual(NFTFactory.TokenStandard.erc721.rawValue, "ERC-721")
        XCTAssertEqual(NFTFactory.TokenStandard.erc721c.rawValue, "ERC-721C")
        XCTAssertEqual(NFTFactory.TokenStandard.erc1155.rawValue, "ERC-1155")
        XCTAssertEqual(NFTFactory.TokenStandard.erc6551.rawValue, "ERC-6551")
    }

    func testNFTTokenStandardDescriptions() {
        XCTAssertTrue(NFTFactory.TokenStandard.erc721.description.contains("standard"))
        XCTAssertTrue(NFTFactory.TokenStandard.erc721c.description.contains("royalt"))
        XCTAssertTrue(NFTFactory.TokenStandard.erc1155.description.contains("Multi"))
        XCTAssertTrue(NFTFactory.TokenStandard.erc6551.description.contains("Token Bound"))
    }

    func testNFTWalletTypeValues() {
        XCTAssertEqual(NFTFactory.WalletType.metamask.rawValue, "metamask")
        XCTAssertEqual(NFTFactory.WalletType.walletConnect.rawValue, "walletConnect")
        XCTAssertEqual(NFTFactory.WalletType.coinbase.rawValue, "coinbase")
        XCTAssertEqual(NFTFactory.WalletType.rainbow.rawValue, "rainbow")
        XCTAssertEqual(NFTFactory.WalletType.secureEnclave.rawValue, "secureEnclave")
    }

    func testNFTRoyaltySplitCreation() {
        let split = NFTFactory.RoyaltySplit(
            address: "0x1234567890123456789012345678901234567890",
            percentage: 50.0,
            name: "Primary Artist"
        )
        XCTAssertEqual(split.address, "0x1234567890123456789012345678901234567890")
        XCTAssertEqual(split.percentage, 50.0)
        XCTAssertEqual(split.name, "Primary Artist")
    }

    func testNFTRoyaltySplitPercentageValidation() {
        let split1 = NFTFactory.RoyaltySplit(address: "0x1", percentage: 100.0, name: "Full")
        XCTAssertEqual(split1.percentage, 100.0)

        let split2 = NFTFactory.RoyaltySplit(address: "0x2", percentage: 0.0, name: "None")
        XCTAssertEqual(split2.percentage, 0.0)

        let split3 = NFTFactory.RoyaltySplit(address: "0x3", percentage: 33.33, name: "Third")
        XCTAssertEqual(split3.percentage, 33.33, accuracy: 0.001)
    }

    // MARK: - ComplianceManager Tests

    @MainActor
    func testComplianceManagerSingletonExists() {
        let manager = ComplianceManager.shared
        XCTAssertNotNil(manager)
    }

    @MainActor
    func testComplianceManagerInitialState() {
        let manager = ComplianceManager.shared
        XCTAssertFalse(manager.isChecking)
    }

    func testComplianceCheckResultStatusValues() {
        XCTAssertEqual(ComplianceManager.ComplianceCheckResult.Status.passed.rawValue, "Passed")
        XCTAssertEqual(ComplianceManager.ComplianceCheckResult.Status.passedWithWarnings.rawValue, "Passed with Warnings")
        XCTAssertEqual(ComplianceManager.ComplianceCheckResult.Status.failed.rawValue, "Failed")
    }

    func testComplianceWarningCategoryValues() {
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Category.gema.rawValue, "GEMA/ISRC")
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Category.vgWort.rawValue, "VG Wort")
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Category.euAIAct.rawValue, "EU AI Act")
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Category.mica.rawValue, "MiCA")
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Category.gdpr.rawValue, "GDPR")
    }

    func testComplianceWarningSeverityValues() {
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Severity.info.rawValue, "Information")
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Severity.warning.rawValue, "Warning")
        XCTAssertEqual(ComplianceManager.ComplianceWarning.Severity.critical.rawValue, "Critical")
    }

    func testComplianceWarningCreation() {
        let warning = ComplianceManager.ComplianceWarning(
            id: UUID(),
            category: .gdpr,
            message: "Test warning message",
            recommendation: "Test recommendation",
            severity: .warning,
            documentationURL: URL(string: "https://gdpr.eu")
        )
        XCTAssertEqual(warning.category, .gdpr)
        XCTAssertEqual(warning.message, "Test warning message")
        XCTAssertEqual(warning.recommendation, "Test recommendation")
        XCTAssertEqual(warning.severity, .warning)
        XCTAssertNotNil(warning.documentationURL)
    }

    func testEUAIActRiskCategoryValues() {
        XCTAssertEqual(ComplianceManager.EUAIActCheckResult.AIRiskCategory.minimal.rawValue, "Minimal Risk")
        XCTAssertEqual(ComplianceManager.EUAIActCheckResult.AIRiskCategory.limited.rawValue, "Limited Risk")
        XCTAssertEqual(ComplianceManager.EUAIActCheckResult.AIRiskCategory.high.rawValue, "High Risk")
        XCTAssertEqual(ComplianceManager.EUAIActCheckResult.AIRiskCategory.unacceptable.rawValue, "Unacceptable Risk")
    }

    func testGDPRLawfulBasisValues() {
        XCTAssertEqual(ComplianceManager.GDPRCheckResult.LawfulBasis.consent.rawValue, "Explicit Consent")
        XCTAssertEqual(ComplianceManager.GDPRCheckResult.LawfulBasis.contract.rawValue, "Contract Performance")
        XCTAssertEqual(ComplianceManager.GDPRCheckResult.LawfulBasis.legalObligation.rawValue, "Legal Obligation")
        XCTAssertEqual(ComplianceManager.GDPRCheckResult.LawfulBasis.vitalInterests.rawValue, "Vital Interests")
        XCTAssertEqual(ComplianceManager.GDPRCheckResult.LawfulBasis.publicInterest.rawValue, "Public Interest")
        XCTAssertEqual(ComplianceManager.GDPRCheckResult.LawfulBasis.legitimateInterests.rawValue, "Legitimate Interests")
    }

    func testBiometricConsentTypeValues() {
        XCTAssertEqual(ComplianceManager.BiometricConsent.ConsentType.nftMetadata.rawValue, "NFT Metadata Storage")
        XCTAssertEqual(ComplianceManager.BiometricConsent.ConsentType.publicBlockchain.rawValue, "Public Blockchain Storage")
        XCTAssertEqual(ComplianceManager.BiometricConsent.ConsentType.anonymizedResearch.rawValue, "Anonymized Research")
        XCTAssertEqual(ComplianceManager.BiometricConsent.ConsentType.thirdPartySharing.rawValue, "Third Party Sharing")
    }

    func testBiometricConsentPurposeValues() {
        XCTAssertEqual(ComplianceManager.BiometricConsent.Purpose.nftCreation.rawValue, "NFT Creation")
        XCTAssertEqual(ComplianceManager.BiometricConsent.Purpose.visualization.rawValue, "Real-time Visualization")
        XCTAssertEqual(ComplianceManager.BiometricConsent.Purpose.analytics.rawValue, "Session Analytics")
        XCTAssertEqual(ComplianceManager.BiometricConsent.Purpose.research.rawValue, "Research (Anonymized)")
    }

    func testBiometricDataCategoryValues() {
        XCTAssertEqual(ComplianceManager.BiometricConsent.DataCategory.heartRate.rawValue, "Heart Rate")
        XCTAssertEqual(ComplianceManager.BiometricConsent.DataCategory.hrv.rawValue, "Heart Rate Variability")
        XCTAssertEqual(ComplianceManager.BiometricConsent.DataCategory.coherence.rawValue, "Coherence Score")
        XCTAssertEqual(ComplianceManager.BiometricConsent.DataCategory.breathing.rawValue, "Breathing Rate")
        XCTAssertEqual(ComplianceManager.BiometricConsent.DataCategory.eeg.rawValue, "EEG Data")
        XCTAssertEqual(ComplianceManager.BiometricConsent.DataCategory.movement.rawValue, "Movement Data")
    }

    func testBiometricConsentCreation() {
        let consent = ComplianceManager.BiometricConsent(
            id: UUID(),
            userID: "user123",
            consentType: .nftMetadata,
            granted: true,
            timestamp: Date(),
            expirationDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
            purposes: [.nftCreation, .visualization],
            dataCategories: [.heartRate, .hrv, .coherence]
        )
        XCTAssertEqual(consent.userID, "user123")
        XCTAssertEqual(consent.consentType, .nftMetadata)
        XCTAssertTrue(consent.granted)
        XCTAssertEqual(consent.purposes.count, 2)
        XCTAssertEqual(consent.dataCategories.count, 3)
    }

    func testContentInfoCreation() {
        let contentInfo = ComplianceManager.ContentInfo(
            hasISRC: true,
            isrcCode: "USRC12345678",
            hasGEMANumber: true,
            gemaWorkNumber: "1234567890",
            containsSamples: false,
            sampleSources: [],
            hasLyrics: true,
            wordCount: 150
        )
        XCTAssertTrue(contentInfo.hasISRC)
        XCTAssertEqual(contentInfo.isrcCode, "USRC12345678")
        XCTAssertTrue(contentInfo.hasGEMANumber)
        XCTAssertEqual(contentInfo.gemaWorkNumber, "1234567890")
        XCTAssertFalse(contentInfo.containsSamples)
        XCTAssertTrue(contentInfo.hasLyrics)
        XCTAssertEqual(contentInfo.wordCount, 150)
    }

    func testAIContentInfoCreation() {
        let aiInfo = ComplianceManager.AIContentInfo(
            containsAIContent: true,
            aiPercentage: 45.0,
            aiTechnologies: ["GPT-4", "DALL-E", "Claude"],
            humanOversight: true,
            aiDisclosurePresent: true
        )
        XCTAssertTrue(aiInfo.containsAIContent)
        XCTAssertEqual(aiInfo.aiPercentage, 45.0)
        XCTAssertEqual(aiInfo.aiTechnologies.count, 3)
        XCTAssertTrue(aiInfo.humanOversight)
        XCTAssertTrue(aiInfo.aiDisclosurePresent)
    }

    func testNFTInfoCreation() {
        let nftInfo = ComplianceManager.NFTInfo(
            isPartOfSeries: true,
            seriesSize: 1000,
            isFractionalized: false,
            hasWhitepaper: false,
            network: .polygon
        )
        XCTAssertTrue(nftInfo.isPartOfSeries)
        XCTAssertEqual(nftInfo.seriesSize, 1000)
        XCTAssertFalse(nftInfo.isFractionalized)
        XCTAssertFalse(nftInfo.hasWhitepaper)
        XCTAssertEqual(nftInfo.network, .polygon)
    }

    func testBiometricInfoCreation() {
        let bioInfo = ComplianceManager.BiometricInfo(
            usesBiometricData: true,
            dataCategories: [.heartRate, .hrv, .coherence],
            userID: "user456",
            storageLocation: .blockchain
        )
        XCTAssertTrue(bioInfo.usesBiometricData)
        XCTAssertEqual(bioInfo.dataCategories.count, 3)
        XCTAssertEqual(bioInfo.userID, "user456")
        XCTAssertEqual(bioInfo.storageLocation, .blockchain)
    }

    func testBiometricStorageLocationValues() {
        XCTAssertEqual(ComplianceManager.BiometricInfo.StorageLocation.local.rawValue, "Local Device")
        XCTAssertEqual(ComplianceManager.BiometricInfo.StorageLocation.cloud.rawValue, "Cloud Server")
        XCTAssertEqual(ComplianceManager.BiometricInfo.StorageLocation.blockchain.rawValue, "Blockchain")
        XCTAssertEqual(ComplianceManager.BiometricInfo.StorageLocation.ipfs.rawValue, "IPFS")
    }

    @MainActor
    func testAIDisclosureLabelGeneration() {
        let manager = ComplianceManager.shared
        let label = manager.generateAIDisclosureLabel(
            aiPercentage: 30.0,
            aiTechnologies: ["GPT-4", "Stable Diffusion"]
        )
        XCTAssertTrue(label.contains("AI CONTENT DISCLOSURE"))
        XCTAssertTrue(label.contains("EU AI Act"))
        XCTAssertTrue(label.contains("30%"))
        XCTAssertTrue(label.contains("GPT-4"))
        XCTAssertTrue(label.contains("Stable Diffusion"))
        XCTAssertTrue(label.contains("Echoelmusic"))
    }

    // MARK: - Integration Tests

    @MainActor
    func testEchoelaToComplianceIntegration() {
        // Verify both managers can be accessed together
        let echoela = EchoelaManager.shared
        let compliance = ComplianceManager.shared

        // Set Echoela context to minting
        echoela.setContext(.minting)
        XCTAssertEqual(echoela.currentContext, .minting)

        // Compliance manager should still be accessible
        XCTAssertNotNil(compliance)
        XCTAssertFalse(compliance.isChecking)
    }

    @MainActor
    func testNFTFactoryToComplianceIntegration() {
        // Verify NFT Factory and Compliance can work together
        let factory = NFTFactory.shared
        let compliance = ComplianceManager.shared

        // Both should be initialized
        XCTAssertNotNil(factory)
        XCTAssertNotNil(compliance)

        // Factory should not be minting
        XCTAssertFalse(factory.isMinting)
    }

    // MARK: - Performance Tests

    func testDeepLinkGenerationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = EchoelaManager.generateDeepLink(category: "test", action: "action")
            }
        }
    }

    func testNFTMetadataCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = NFTFactory.NFTMetadata(
                    name: "Test",
                    description: "Description",
                    artist: "Artist",
                    createdDate: Date(),
                    network: .polygon
                )
            }
        }
    }

    func testComplianceWarningCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = ComplianceManager.ComplianceWarning(
                    id: UUID(),
                    category: .gdpr,
                    message: "Test",
                    recommendation: "Test",
                    severity: .warning,
                    documentationURL: nil
                )
            }
        }
    }
}
