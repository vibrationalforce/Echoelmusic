// StatisticalValidation.swift
// Echoelmusic - Statistical Validation Framework for RL
//
// Reproducible experiments with proper statistical testing
// Based on: Henderson et al. (2018). Deep Reinforcement Learning that Matters. AAAI.

import Foundation
import Accelerate
import os.log

private let statsLogger = Logger(subsystem: "com.echoelmusic.rl", category: "Statistics")

// MARK: - Statistical References

public struct StatisticalReferences {
    public static let hendersonRL2018 = "Henderson, P., et al. (2018). Deep Reinforcement Learning that Matters. AAAI 2018."
    public static let colas2019 = "Colas, C., et al. (2019). How Many Random Seeds? Statistical Power Analysis in Deep RL. arXiv:1806.08295"
    public static let agarwal2021 = "Agarwal, R., et al. (2021). Deep Reinforcement Learning at the Edge of Statistical Precipice. NeurIPS 2021."
}

// MARK: - Experiment Configuration

public struct ExperimentConfig: Codable {
    public var experimentName: String
    public var algorithmName: String
    public var randomSeeds: [UInt64]
    public var numEpisodes: Int
    public var evaluationInterval: Int
    public var evaluationEpisodes: Int
    public var confidenceLevel: Double  // e.g., 0.95 for 95% CI

    public init(
        experimentName: String,
        algorithmName: String,
        numSeeds: Int = 10,  // Henderson et al. recommend >= 5
        numEpisodes: Int = 1000,
        evaluationInterval: Int = 100,
        evaluationEpisodes: Int = 10,
        confidenceLevel: Double = 0.95
    ) {
        self.experimentName = experimentName
        self.algorithmName = algorithmName
        self.randomSeeds = (0..<numSeeds).map { _ in UInt64.random(in: 0...UInt64.max) }
        self.numEpisodes = numEpisodes
        self.evaluationInterval = evaluationInterval
        self.evaluationEpisodes = evaluationEpisodes
        self.confidenceLevel = confidenceLevel
    }
}

// MARK: - Experiment Results

public struct ExperimentResults: Codable {
    public var config: ExperimentConfig
    public var runResults: [RunResult]
    public var aggregatedMetrics: AggregatedMetrics?
    public var statisticalTests: [StatisticalTest]
    public var timestamp: Date

    public struct RunResult: Codable {
        public var seed: UInt64
        public var episodeRewards: [Double]
        public var evaluationRewards: [Double]
        public var trainingTime: TimeInterval
        public var finalPerformance: Double
    }

    public struct AggregatedMetrics: Codable {
        public var meanFinalReward: Double
        public var stdFinalReward: Double
        public var confidenceInterval: (lower: Double, upper: Double)
        public var interquartileRange: (q1: Double, median: Double, q3: Double)
        public var sampleEfficiency: Double  // Episodes to reach threshold
        public var learningCurves: [[Double]]  // Mean ± std at each evaluation
    }

    public struct StatisticalTest: Codable {
        public var testName: String
        public var testStatistic: Double
        public var pValue: Double
        public var effectSize: Double
        public var isSignificant: Bool
        public var interpretation: String
    }
}

// MARK: - Statistical Utilities

public final class StatisticalUtils {

    // MARK: - Descriptive Statistics

    /// Calculate mean
    public static func mean(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Calculate sample variance (Bessel's correction)
    public static func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let m = mean(values)
        let squaredDiffs = values.map { ($0 - m) * ($0 - m) }
        return squaredDiffs.reduce(0, +) / Double(values.count - 1)
    }

    /// Calculate sample standard deviation
    public static func standardDeviation(_ values: [Double]) -> Double {
        sqrt(variance(values))
    }

    /// Calculate standard error of the mean
    public static func standardError(_ values: [Double]) -> Double {
        standardDeviation(values) / sqrt(Double(values.count))
    }

    /// Calculate median
    public static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let n = sorted.count
        if n % 2 == 0 {
            return (sorted[n/2 - 1] + sorted[n/2]) / 2
        }
        return sorted[n/2]
    }

    /// Calculate percentile
    public static func percentile(_ values: [Double], p: Double) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let index = p * Double(sorted.count - 1)
        let lower = Int(index)
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = index - Double(lower)
        return sorted[lower] * (1 - fraction) + sorted[upper] * fraction
    }

    /// Interquartile range
    public static func iqr(_ values: [Double]) -> (q1: Double, median: Double, q3: Double) {
        (percentile(values, p: 0.25), median(values), percentile(values, p: 0.75))
    }

    // MARK: - Confidence Intervals

    /// Calculate confidence interval for mean using t-distribution
    public static func confidenceInterval(_ values: [Double], level: Double = 0.95) -> (lower: Double, upper: Double) {
        guard values.count >= 2 else { return (0, 0) }

        let m = mean(values)
        let se = standardError(values)
        let df = Double(values.count - 1)

        // t-critical value (approximation for common levels)
        let tCritical = tDistributionCriticalValue(df: df, alpha: 1 - level)

        let margin = tCritical * se
        return (m - margin, m + margin)
    }

    /// Bootstrap confidence interval (non-parametric)
    /// Efron & Tibshirani (1993). An Introduction to the Bootstrap.
    public static func bootstrapCI(
        _ values: [Double],
        statistic: ([Double]) -> Double = mean,
        level: Double = 0.95,
        numBootstraps: Int = 10000
    ) -> (lower: Double, upper: Double) {
        var bootstrapStats: [Double] = []

        for _ in 0..<numBootstraps {
            var sample: [Double] = []
            for _ in 0..<values.count {
                sample.append(values[Int.random(in: 0..<values.count)])
            }
            bootstrapStats.append(statistic(sample))
        }

        let alpha = (1 - level) / 2
        return (
            percentile(bootstrapStats, p: alpha),
            percentile(bootstrapStats, p: 1 - alpha)
        )
    }

    // MARK: - Hypothesis Tests

    /// Welch's t-test (unequal variances)
    /// Reference: Welch, B.L. (1947). The generalization of 'student's' problem.
    public static func welchTTest(_ group1: [Double], _ group2: [Double]) -> (t: Double, p: Double, df: Double) {
        let n1 = Double(group1.count)
        let n2 = Double(group2.count)
        let m1 = mean(group1)
        let m2 = mean(group2)
        let v1 = variance(group1)
        let v2 = variance(group2)

        let se = sqrt(v1/n1 + v2/n2)
        let t = (m1 - m2) / se

        // Welch-Satterthwaite degrees of freedom
        let df = pow(v1/n1 + v2/n2, 2) /
                 (pow(v1/n1, 2)/(n1-1) + pow(v2/n2, 2)/(n2-1))

        let p = 2 * (1 - tDistributionCDF(t: abs(t), df: df))

        return (t, p, df)
    }

    /// Mann-Whitney U test (non-parametric)
    /// Reference: Mann, H.B., & Whitney, D.R. (1947). Annals of Mathematical Statistics.
    public static func mannWhitneyU(_ group1: [Double], _ group2: [Double]) -> (u: Double, p: Double) {
        let n1 = Double(group1.count)
        let n2 = Double(group2.count)

        // Rank all values
        let combined = (group1.map { ($0, 1) } + group2.map { ($0, 2) }).sorted { $0.0 < $1.0 }

        var ranks: [Int: Double] = [:]
        var i = 0
        while i < combined.count {
            var j = i
            while j < combined.count && combined[j].0 == combined[i].0 {
                j += 1
            }
            let avgRank = Double(i + j + 1) / 2  // Average rank for ties
            for k in i..<j {
                ranks[k] = avgRank
            }
            i = j
        }

        // Sum of ranks for group 1
        var r1: Double = 0
        for (idx, (_, group)) in combined.enumerated() {
            if group == 1 {
                r1 += ranks[idx]!
            }
        }

        // U statistic
        let u1 = n1 * n2 + n1 * (n1 + 1) / 2 - r1
        let u2 = n1 * n2 - u1
        let u = min(u1, u2)

        // Normal approximation for p-value (large samples)
        let mu = n1 * n2 / 2
        let sigma = sqrt(n1 * n2 * (n1 + n2 + 1) / 12)
        let z = (u - mu) / sigma
        let p = 2 * normalCDF(-abs(z))

        return (u, p)
    }

    /// Paired t-test
    public static func pairedTTest(_ before: [Double], _ after: [Double]) -> (t: Double, p: Double) {
        guard before.count == after.count else { return (0, 1) }

        let differences = zip(before, after).map { $1 - $0 }
        let m = mean(differences)
        let se = standardError(differences)
        let t = m / se
        let df = Double(differences.count - 1)
        let p = 2 * (1 - tDistributionCDF(t: abs(t), df: df))

        return (t, p)
    }

    // MARK: - Effect Size

    /// Cohen's d effect size
    /// Reference: Cohen, J. (1988). Statistical Power Analysis for the Behavioral Sciences.
    public static func cohensD(_ group1: [Double], _ group2: [Double]) -> Double {
        let m1 = mean(group1)
        let m2 = mean(group2)
        let v1 = variance(group1)
        let v2 = variance(group2)
        let n1 = Double(group1.count)
        let n2 = Double(group2.count)

        // Pooled standard deviation
        let pooledVar = ((n1 - 1) * v1 + (n2 - 1) * v2) / (n1 + n2 - 2)
        let pooledStd = sqrt(pooledVar)

        return (m1 - m2) / pooledStd
    }

    /// Interpret Cohen's d
    public static func interpretCohensD(_ d: Double) -> String {
        let absD = abs(d)
        if absD < 0.2 { return "negligible" }
        if absD < 0.5 { return "small" }
        if absD < 0.8 { return "medium" }
        return "large"
    }

    // MARK: - Distribution Functions

    /// Normal CDF (approximation by Abramowitz & Stegun)
    public static func normalCDF(_ x: Double) -> Double {
        let a1 = 0.254829592
        let a2 = -0.284496736
        let a3 = 1.421413741
        let a4 = -1.453152027
        let a5 = 1.061405429
        let p = 0.3275911

        let sign = x < 0 ? -1.0 : 1.0
        let absX = abs(x) / sqrt(2.0)

        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)

        return 0.5 * (1.0 + sign * y)
    }

    /// t-distribution CDF (approximation)
    public static func tDistributionCDF(t: Double, df: Double) -> Double {
        // Use normal approximation for large df
        if df > 100 {
            return normalCDF(t)
        }

        // Beta function incomplete calculation
        let x = df / (df + t * t)
        let a = df / 2
        let b = 0.5

        let beta = incompleteBeta(x: x, a: a, b: b)
        return 1 - 0.5 * beta
    }

    /// t-distribution critical value (approximation)
    public static func tDistributionCriticalValue(df: Double, alpha: Double) -> Double {
        // Approximation using normal quantile + correction
        let z = normalQuantile(1 - alpha / 2)

        // Hill's approximation for t quantile
        let g1 = (pow(z, 3) + z) / 4
        let g2 = (5 * pow(z, 5) + 16 * pow(z, 3) + 3 * z) / 96
        let g3 = (3 * pow(z, 7) + 19 * pow(z, 5) + 17 * pow(z, 3) - 15 * z) / 384

        return z + g1/df + g2/pow(df, 2) + g3/pow(df, 3)
    }

    /// Normal quantile (inverse CDF)
    public static func normalQuantile(_ p: Double) -> Double {
        // Rational approximation (Abramowitz & Stegun 26.2.23)
        guard p > 0 && p < 1 else { return 0 }

        let t: Double
        if p < 0.5 {
            t = sqrt(-2 * log(p))
        } else {
            t = sqrt(-2 * log(1 - p))
        }

        let c0 = 2.515517
        let c1 = 0.802853
        let c2 = 0.010328
        let d1 = 1.432788
        let d2 = 0.189269
        let d3 = 0.001308

        var result = t - (c0 + c1*t + c2*t*t) / (1 + d1*t + d2*t*t + d3*t*t*t)

        if p < 0.5 {
            result = -result
        }

        return result
    }

    /// Incomplete beta function (approximation)
    private static func incompleteBeta(x: Double, a: Double, b: Double) -> Double {
        // Simple continued fraction approximation
        if x == 0 { return 0 }
        if x == 1 { return 1 }

        let bt = exp(
            lgamma(a + b) - lgamma(a) - lgamma(b) +
            a * log(x) + b * log(1 - x)
        )

        if x < (a + 1) / (a + b + 2) {
            return bt * betaCF(x: x, a: a, b: b) / a
        } else {
            return 1 - bt * betaCF(x: 1 - x, a: b, b: a) / b
        }
    }

    private static func betaCF(x: Double, a: Double, b: Double) -> Double {
        let maxIterations = 100
        let epsilon = 3e-7

        var am = 1.0
        var bm = 1.0
        var az = 1.0

        let qab = a + b
        let qap = a + 1
        let qam = a - 1
        var bz = 1 - qab * x / qap

        for m in 1...maxIterations {
            let em = Double(m)
            let tem = em + em
            var d = em * (b - m) * x / ((qam + tem) * (a + tem))

            let ap = az + d * am
            let bp = bz + d * bm
            d = -(a + em) * (qab + em) * x / ((a + tem) * (qap + tem))

            let app = ap + d * az
            let bpp = bp + d * bz

            let aold = az
            am = ap / bpp
            bm = bp / bpp
            az = app / bpp
            bz = 1

            if abs(az - aold) < epsilon * abs(az) {
                return az
            }
        }

        return az
    }
}

// MARK: - Experiment Runner

@MainActor
public final class ExperimentRunner: ObservableObject {
    public static let shared = ExperimentRunner()

    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var currentSeed: Int = 0
    @Published public private(set) var currentEpisode: Int = 0
    @Published public private(set) var progress: Double = 0

    private init() {
        statsLogger.info("Experiment Runner initialized")
    }

    /// Run a complete experiment with multiple seeds
    public func runExperiment(
        config: ExperimentConfig,
        createAgent: (UInt64) -> PPOAgent,
        createEnvironment: () -> MusicRLEnvironment
    ) async -> ExperimentResults {
        isRunning = true
        defer { isRunning = false }

        var runResults: [ExperimentResults.RunResult] = []
        let totalWork = Double(config.randomSeeds.count * config.numEpisodes)
        var completedWork = 0.0

        for (seedIndex, seed) in config.randomSeeds.enumerated() {
            currentSeed = seedIndex

            // Set random seed for reproducibility
            srand48(Int(seed))

            let agent = createAgent(seed)
            let environment = createEnvironment()

            var episodeRewards: [Double] = []
            var evaluationRewards: [Double] = []
            let startTime = Date()

            for episode in 0..<config.numEpisodes {
                currentEpisode = episode

                // Training episode
                var state = environment.reset()
                var episodeReward: Double = 0
                var done = false

                while !done {
                    let (action, _) = agent.selectAction(state: state)
                    let (nextState, reward, isDone) = environment.step(action: action)
                    agent.storeTransition(state: state, action: action, reward: reward, done: isDone)
                    state = nextState
                    episodeReward += Double(reward)
                    done = isDone
                }

                episodeRewards.append(episodeReward)
                let _ = agent.update()

                // Evaluation
                if (episode + 1) % config.evaluationInterval == 0 {
                    var evalRewards: [Double] = []
                    for _ in 0..<config.evaluationEpisodes {
                        var evalState = environment.reset()
                        var evalReward: Double = 0
                        var evalDone = false
                        while !evalDone {
                            let (action, _) = agent.selectAction(state: evalState)
                            let (nextState, reward, isDone) = environment.step(action: action)
                            evalState = nextState
                            evalReward += Double(reward)
                            evalDone = isDone
                        }
                        evalRewards.append(evalReward)
                    }
                    evaluationRewards.append(StatisticalUtils.mean(evalRewards))
                }

                completedWork += 1
                progress = completedWork / totalWork
            }

            let trainingTime = Date().timeIntervalSince(startTime)
            let finalPerformance = evaluationRewards.last ?? StatisticalUtils.mean(episodeRewards.suffix(100))

            runResults.append(ExperimentResults.RunResult(
                seed: seed,
                episodeRewards: episodeRewards,
                evaluationRewards: evaluationRewards,
                trainingTime: trainingTime,
                finalPerformance: finalPerformance
            ))

            statsLogger.info("Completed seed \(seedIndex + 1)/\(config.randomSeeds.count), final performance: \(finalPerformance)")
        }

        // Aggregate results
        let aggregated = aggregateResults(runResults, config: config)
        let tests = performStatisticalTests(runResults)

        return ExperimentResults(
            config: config,
            runResults: runResults,
            aggregatedMetrics: aggregated,
            statisticalTests: tests,
            timestamp: Date()
        )
    }

    /// Compare two experiments
    public func compareExperiments(
        experiment1: ExperimentResults,
        experiment2: ExperimentResults
    ) -> [ExperimentResults.StatisticalTest] {
        let perf1 = experiment1.runResults.map { $0.finalPerformance }
        let perf2 = experiment2.runResults.map { $0.finalPerformance }

        var tests: [ExperimentResults.StatisticalTest] = []

        // Welch's t-test
        let (t, pWelch, df) = StatisticalUtils.welchTTest(perf1, perf2)
        tests.append(ExperimentResults.StatisticalTest(
            testName: "Welch's t-test",
            testStatistic: t,
            pValue: pWelch,
            effectSize: StatisticalUtils.cohensD(perf1, perf2),
            isSignificant: pWelch < 0.05,
            interpretation: "t(\(String(format: "%.1f", df))) = \(String(format: "%.3f", t)), p = \(String(format: "%.4f", pWelch))"
        ))

        // Mann-Whitney U test
        let (u, pMW) = StatisticalUtils.mannWhitneyU(perf1, perf2)
        tests.append(ExperimentResults.StatisticalTest(
            testName: "Mann-Whitney U",
            testStatistic: u,
            pValue: pMW,
            effectSize: 0,  // Effect size different for U test
            isSignificant: pMW < 0.05,
            interpretation: "U = \(String(format: "%.1f", u)), p = \(String(format: "%.4f", pMW))"
        ))

        return tests
    }

    private func aggregateResults(_ runs: [ExperimentResults.RunResult], config: ExperimentConfig) -> ExperimentResults.AggregatedMetrics {
        let finalPerformances = runs.map { $0.finalPerformance }

        let meanFinal = StatisticalUtils.mean(finalPerformances)
        let stdFinal = StatisticalUtils.standardDeviation(finalPerformances)
        let ci = StatisticalUtils.confidenceInterval(finalPerformances, level: config.confidenceLevel)
        let iqr = StatisticalUtils.iqr(finalPerformances)

        // Calculate sample efficiency (episodes to reach 80% of max)
        let threshold = meanFinal * 0.8
        var sampleEfficiency: Double = Double(config.numEpisodes)
        for run in runs {
            for (episode, reward) in run.episodeRewards.enumerated() {
                if reward >= threshold {
                    sampleEfficiency = min(sampleEfficiency, Double(episode))
                    break
                }
            }
        }

        // Learning curves: mean ± std at each evaluation point
        let numEvalPoints = runs[0].evaluationRewards.count
        var learningCurves: [[Double]] = []
        for point in 0..<numEvalPoints {
            let values = runs.map { $0.evaluationRewards[point] }
            let m = StatisticalUtils.mean(values)
            let s = StatisticalUtils.standardDeviation(values)
            learningCurves.append([m - s, m, m + s])
        }

        return ExperimentResults.AggregatedMetrics(
            meanFinalReward: meanFinal,
            stdFinalReward: stdFinal,
            confidenceInterval: ci,
            interquartileRange: iqr,
            sampleEfficiency: sampleEfficiency,
            learningCurves: learningCurves
        )
    }

    private func performStatisticalTests(_ runs: [ExperimentResults.RunResult]) -> [ExperimentResults.StatisticalTest] {
        var tests: [ExperimentResults.StatisticalTest] = []

        let finalPerformances = runs.map { $0.finalPerformance }

        // Test if mean is significantly different from zero
        let se = StatisticalUtils.standardError(finalPerformances)
        let mean = StatisticalUtils.mean(finalPerformances)
        let t = mean / se
        let df = Double(finalPerformances.count - 1)
        let p = 2 * (1 - StatisticalUtils.tDistributionCDF(t: abs(t), df: df))

        tests.append(ExperimentResults.StatisticalTest(
            testName: "One-sample t-test (μ ≠ 0)",
            testStatistic: t,
            pValue: p,
            effectSize: mean / StatisticalUtils.standardDeviation(finalPerformances),
            isSignificant: p < 0.05,
            interpretation: "t(\(Int(df))) = \(String(format: "%.3f", t)), p = \(String(format: "%.4f", p))"
        ))

        return tests
    }
}
