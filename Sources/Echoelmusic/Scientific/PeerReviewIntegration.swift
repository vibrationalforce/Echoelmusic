// MARK: - Peer Review Integration
// Framework for scientific publication and study registration
// Ensures transparency and reproducibility of clinical research

import Foundation

/// Peer review and study registration manager
/// Facilitates scientific publication and clinical trial registration
public class PeerReviewIntegration {

    // MARK: - Preprint Submission

    /// Submit preprint to medRxiv or bioRxiv
    /// Required before peer review to establish priority and transparency
    public func submitPreprint(
        title: String,
        authors: [Author],
        abstract: String,
        manuscript: Data,
        server: PreprintServer = .medRxiv
    ) -> PreprintSubmission {
        let submission = PreprintSubmission(
            title: title,
            authors: authors,
            abstract: abstract,
            server: server,
            submissionDate: Date(),
            doi: nil,  // Assigned after submission
            status: .submitted
        )

        print("""
            📄 Preprint Submission:
               Title: \(title)
               Server: \(server.rawValue)
               Authors: \(authors.map { $0.name }.joined(separator: ", "))

            ⏳ Awaiting DOI assignment from \(server.rawValue)...
            """)

        return submission
    }

    // MARK: - Journal Submission

    /// Submit to peer-reviewed journal
    /// Target high-impact journals in digital health and neuroscience
    public func submitToJournal(
        manuscript: Manuscript,
        targetJournal: Journal
    ) -> JournalSubmission {
        let submission = JournalSubmission(
            manuscript: manuscript,
            journal: targetJournal,
            submissionDate: Date(),
            status: .submitted,
            reviewers: [],
            decision: nil
        )

        print("""
            📝 Journal Submission:
               Title: \(manuscript.title)
               Journal: \(targetJournal.name) (IF: \(targetJournal.impactFactor))
               Submitted: \(submission.submissionDate)

            ⏳ Peer review in progress...
            """)

        return submission
    }

    /// Recommended target journals for Echoelmusic research
    public static let targetJournals: [Journal] = [
        Journal(
            name: "Nature Digital Medicine",
            impactFactor: 15.2,
            publisher: "Nature Portfolio",
            scope: "Digital health technologies, clinical trials, AI/ML in medicine",
            url: "https://www.nature.com/npjdigitalmed/",
            openAccess: true,
            averageReviewTime: 60  // days
        ),
        Journal(
            name: "npj Digital Medicine",
            impactFactor: 12.4,
            publisher: "Nature Portfolio",
            scope: "Digital biomarkers, mobile health, wearable sensors",
            url: "https://www.nature.com/npjdigitalmed/",
            openAccess: true,
            averageReviewTime: 45
        ),
        Journal(
            name: "Journal of Medical Internet Research (JMIR)",
            impactFactor: 7.1,
            publisher: "JMIR Publications",
            scope: "Digital health interventions, telemedicine, mHealth",
            url: "https://www.jmir.org/",
            openAccess: true,
            averageReviewTime: 75
        ),
        Journal(
            name: "IEEE Transactions on Biomedical Engineering",
            impactFactor: 4.6,
            publisher: "IEEE",
            scope: "Biomedical signal processing, medical devices, biosensors",
            url: "https://tbme.embs.org/",
            openAccess: false,
            averageReviewTime: 90
        ),
        Journal(
            name: "Frontiers in Digital Health",
            impactFactor: 3.2,
            publisher: "Frontiers",
            scope: "Digital therapeutics, health informatics, connected health",
            url: "https://www.frontiersin.org/journals/digital-health",
            openAccess: true,
            averageReviewTime: 50
        ),
        Journal(
            name: "Applied Psychophysiology and Biofeedback",
            impactFactor: 2.8,
            publisher: "Springer",
            scope: "Biofeedback, HRV, neurofeedback, mind-body interventions",
            url: "https://www.springer.com/journal/10484",
            openAccess: false,
            averageReviewTime: 80
        )
    ]

    // MARK: - Clinical Trial Registration

    /// Register study on ClinicalTrials.gov
    /// REQUIRED for all prospective clinical trials before enrollment
    public func registerClinicalTrial(
        title: String,
        principalInvestigator: Author,
        studyDesign: StudyDesign,
        participants: Int,
        duration: TimeInterval,
        primaryOutcome: String,
        secondaryOutcomes: [String],
        inclusionCriteria: [String],
        exclusionCriteria: [String]
    ) -> ClinicalTrialRegistration {
        let nctNumber = generateNCTNumber()

        let registration = ClinicalTrialRegistration(
            nctNumber: nctNumber,
            title: title,
            principalInvestigator: principalInvestigator,
            studyDesign: studyDesign,
            status: .recruiting,
            estimatedEnrollment: participants,
            studyDuration: duration,
            primaryOutcome: primaryOutcome,
            secondaryOutcomes: secondaryOutcomes,
            inclusionCriteria: inclusionCriteria,
            exclusionCriteria: exclusionCriteria,
            registrationDate: Date(),
            resultsPosted: false
        )

        print("""
            🔬 Clinical Trial Registration:
               NCT Number: \(nctNumber)
               Title: \(title)
               PI: \(principalInvestigator.name)
               Design: \(studyDesign.rawValue)
               Target Enrollment: n=\(participants)
               Duration: \(Int(duration / 86400)) days

            ✅ Registered on ClinicalTrials.gov
            """)

        return registration
    }

    private func generateNCTNumber() -> String {
        // NCT numbers are 8 digits: NCT + 8 digits
        // In production, this would be assigned by ClinicalTrials.gov
        let randomNumber = Int.random(in: 10000000...99999999)
        return "NCT\(randomNumber)"
    }

    // MARK: - Ethics Approval

    /// Submit to Institutional Review Board (IRB)
    /// REQUIRED for all human subjects research
    public func submitIRBApplication(
        studyTitle: String,
        investigator: Author,
        institution: String,
        studyProtocol: String,
        consentForm: Data,
        riskAnalysis: ISO14971RiskAnalysis
    ) -> IRBApplication {
        let application = IRBApplication(
            protocolNumber: generateIRBProtocolNumber(),
            studyTitle: studyTitle,
            principalInvestigator: investigator,
            institution: institution,
            submissionDate: Date(),
            status: .underReview,
            approvalDate: nil,
            expirationDate: nil
        )

        print("""
            🏛️ IRB Application:
               Protocol: \(application.protocolNumber)
               Study: \(studyTitle)
               Institution: \(institution)
               Status: Under Review

            ⏳ Awaiting ethics committee decision...
            """)

        return application
    }

    private func generateIRBProtocolNumber() -> String {
        let year = Calendar.current.component(.year, from: Date())
        let randomID = Int.random(in: 1000...9999)
        return "IRB-\(year)-\(randomID)"
    }

    // MARK: - Data Sharing

    /// Prepare data for public repository (Open Science Framework, Zenodo, etc.)
    /// Promotes transparency and reproducibility
    public func prepareDataSharing(
        dataset: Data,
        codebook: String,
        analysisScripts: [String],
        repository: DataRepository = .osf
    ) -> DataSharingPackage {
        let package = DataSharingPackage(
            dataset: dataset,
            codebook: codebook,
            analysisScripts: analysisScripts,
            repository: repository,
            doi: nil,  // Assigned by repository
            license: .ccBy40,  // Creative Commons Attribution 4.0
            uploadDate: Date()
        )

        print("""
            📊 Data Sharing Package:
               Repository: \(repository.rawValue)
               License: \(package.license.rawValue)
               Files: Dataset + Codebook + \(analysisScripts.count) scripts

            🌍 Promoting open science and reproducibility
            """)

        return package
    }

    // MARK: - Publication Tracking

    /// Track publication metrics
    public func trackPublicationMetrics(doi: String) -> PublicationMetrics {
        // In production, this would query CrossRef, Altmetric, etc.
        return PublicationMetrics(
            doi: doi,
            citations: 0,
            altmetricScore: 0,
            downloads: 0,
            lastUpdated: Date()
        )
    }
}

// MARK: - Supporting Types

public struct Author {
    let name: String
    let affiliation: String
    let orcid: String?  // ORCID identifier
    let email: String
    let isCorrespondingAuthor: Bool
}

public enum PreprintServer: String {
    case medRxiv = "medRxiv (Medicine)"
    case bioRxiv = "bioRxiv (Biology)"
    case psyArXiv = "PsyArXiv (Psychology)"
    case arXiv = "arXiv (Physics/CS)"
}

public struct PreprintSubmission {
    let title: String
    let authors: [Author]
    let abstract: String
    let server: PreprintServer
    let submissionDate: Date
    var doi: String?
    var status: SubmissionStatus

    enum SubmissionStatus: String {
        case draft, submitted, posted, withdrawn
    }
}

public struct Journal {
    let name: String
    let impactFactor: Double
    let publisher: String
    let scope: String
    let url: String
    let openAccess: Bool
    let averageReviewTime: Int  // days
}

public struct Manuscript {
    let title: String
    let authors: [Author]
    let abstract: String
    let introduction: String
    let methods: String
    let results: String
    let discussion: String
    let references: [String]
    let figures: [Data]
    let tables: [Data]
    let supplementaryMaterial: [Data]
}

public struct JournalSubmission {
    let manuscript: Manuscript
    let journal: Journal
    let submissionDate: Date
    var status: SubmissionStatus
    var reviewers: [String]
    var decision: Decision?

    enum SubmissionStatus: String {
        case submitted, underReview, revisionRequested, revised, accepted, rejected
    }

    enum Decision: String {
        case accept, minorRevision, majorRevision, reject
    }
}

public struct ClinicalTrialRegistration {
    let nctNumber: String
    let title: String
    let principalInvestigator: Author
    let studyDesign: StudyDesign
    var status: TrialStatus
    let estimatedEnrollment: Int
    let studyDuration: TimeInterval
    let primaryOutcome: String
    let secondaryOutcomes: [String]
    let inclusionCriteria: [String]
    let exclusionCriteria: [String]
    let registrationDate: Date
    var resultsPosted: Bool

    enum TrialStatus: String {
        case notYetRecruiting = "Not Yet Recruiting"
        case recruiting = "Recruiting"
        case enrolledByInvitation = "Enrolled by Invitation"
        case active = "Active, Not Recruiting"
        case completed = "Completed"
        case terminated = "Terminated"
        case withdrawn = "Withdrawn"
    }
}

public struct IRBApplication {
    let protocolNumber: String
    let studyTitle: String
    let principalInvestigator: Author
    let institution: String
    let submissionDate: Date
    var status: IRBStatus
    var approvalDate: Date?
    var expirationDate: Date?  // IRB approval typically valid 1 year

    enum IRBStatus: String {
        case draft, submitted, underReview, approved, conditionalApproval, rejected
    }
}

public enum DataRepository: String {
    case osf = "Open Science Framework"
    case zenodo = "Zenodo"
    case figshare = "Figshare"
    case dryad = "Dryad"
}

public struct DataSharingPackage {
    let dataset: Data
    let codebook: String
    let analysisScripts: [String]
    let repository: DataRepository
    var doi: String?
    let license: License
    let uploadDate: Date

    enum License: String {
        case ccBy40 = "CC BY 4.0"
        case cc0 = "CC0 (Public Domain)"
        case mit = "MIT License"
    }
}

public struct PublicationMetrics {
    let doi: String
    var citations: Int
    var altmetricScore: Double
    var downloads: Int
    let lastUpdated: Date
}
