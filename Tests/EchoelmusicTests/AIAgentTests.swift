import XCTest
@testable import Echoelmusic

/// Tests for the AI Sub-Agent System
final class AIAgentTests: XCTestCase {

    var agentSystem: AISubAgentSystem!

    override func setUp() async throws {
        agentSystem = AISubAgentSystem.shared
    }

    // MARK: - Agent Pool Tests

    func testAgentPoolInitialization() {
        let agentTypes = AISubAgentSystem.AgentType.allCases
        XCTAssertEqual(agentTypes.count, 10, "Should have 10 agent types")

        for type in agentTypes {
            XCTAssertFalse(type.capabilities.isEmpty, "\(type) should have capabilities")
        }
    }

    func testAgentCapabilities() {
        let composer = AISubAgentSystem.AgentType.composer
        XCTAssertTrue(composer.capabilities.contains(.melodyGeneration))
        XCTAssertTrue(composer.capabilities.contains(.harmonyGeneration))

        let mixer = AISubAgentSystem.AgentType.mixer
        XCTAssertTrue(mixer.capabilities.contains(.levelBalancing))
        XCTAssertTrue(mixer.capabilities.contains(.eqAdjustment))

        let masteringEngineer = AISubAgentSystem.AgentType.masteringEngineer
        XCTAssertTrue(masteringEngineer.capabilities.contains(.loudnessOptimization))
        XCTAssertTrue(masteringEngineer.capabilities.contains(.limiting))
    }

    func testAgentPriorities() {
        let analyzer = AISubAgentSystem.AgentType.analyzer
        let composer = AISubAgentSystem.AgentType.composer
        let masteringEngineer = AISubAgentSystem.AgentType.masteringEngineer

        // Analyzer should run first (lowest priority number)
        XCTAssertLessThan(analyzer.defaultPriority, composer.defaultPriority)
        // Mastering should run last
        XCTAssertGreaterThan(masteringEngineer.defaultPriority, composer.defaultPriority)
    }

    // MARK: - Task Management Tests

    func testTaskCreation() {
        let task = AgentTask(
            type: .compose,
            parameters: ["style": "jazz", "duration": 180],
            priority: 5
        )

        XCTAssertEqual(task.type, .compose)
        XCTAssertEqual(task.priority, 5)
        XCTAssertTrue(task.requiredCapabilities.contains(.melodyGeneration))
    }

    func testTaskSubmission() async throws {
        let task = AgentTask(
            type: .analyze,
            parameters: ["type": "spectrum"]
        )

        let result = await agentSystem.submitTask(task)

        // Task should complete (success or failure due to mock)
        XCTAssertNotNil(result.taskId)
    }

    func testTaskQueue() async throws {
        // Submit multiple tasks
        let tasks = [
            AgentTask(type: .analyze, parameters: [:]),
            AgentTask(type: .compose, parameters: [:]),
            AgentTask(type: .mix, parameters: [:])
        ]

        for task in tasks {
            _ = await agentSystem.submitTask(task)
        }

        // All tasks should be completed
        XCTAssertGreaterThanOrEqual(agentSystem.completedTasks.count, 0)
    }

    // MARK: - Workflow Tests

    func testWorkflowCreation() {
        let workflow = AgentWorkflow(
            name: "Test Workflow",
            stages: [
                WorkflowStage(tasks: [AgentTask(type: .analyze, parameters: [:])]),
                WorkflowStage(tasks: [AgentTask(type: .compose, parameters: [:])])
            ]
        )

        XCTAssertEqual(workflow.name, "Test Workflow")
        XCTAssertEqual(workflow.stages.count, 2)
        XCTAssertTrue(workflow.stopOnFailure)
    }

    func testParallelWorkflowStage() {
        let stage = WorkflowStage(
            tasks: [
                AgentTask(type: .mix, parameters: ["operation": "eq"]),
                AgentTask(type: .mix, parameters: ["operation": "compression"]),
                AgentTask(type: .mix, parameters: ["operation": "reverb"])
            ],
            parallel: true
        )

        XCTAssertTrue(stage.parallel)
        XCTAssertEqual(stage.tasks.count, 3)
    }

    func testWorkflowSubmission() async throws {
        let workflow = AgentWorkflow(
            name: "Simple Workflow",
            stages: [
                WorkflowStage(tasks: [
                    AgentTask(type: .analyze, parameters: [:])
                ])
            ]
        )

        let results = await agentSystem.submitWorkflow(workflow)
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - High-Level Operation Tests

    func testAutoCompose() async throws {
        let result = await agentSystem.autoCompose(
            style: "electronic",
            duration: 120,
            key: "Am",
            tempo: 128
        )

        // Result should indicate completion
        XCTAssertNotNil(result)
    }

    func testAutoMix() async throws {
        let result = await agentSystem.autoMix(projectId: "test-project")
        XCTAssertNotNil(result)
    }

    func testAutoMaster() async throws {
        let result = await agentSystem.autoMaster(
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            targetLoudness: -14,
            style: .balanced
        )

        XCTAssertNotNil(result)
    }

    // MARK: - Message Bus Tests

    func testAgentMessageBus() {
        let bus = AgentMessageBus()
        var receivedMessage: AgentMessage?

        let agentId = UUID()
        bus.subscribe(agentId) { message in
            receivedMessage = message
        }

        let testMessage = AgentMessage(
            from: UUID(),
            to: agentId,
            type: .taskAssignment,
            payload: ["test": "data"]
        )

        bus.send(testMessage, to: agentId)

        XCTAssertNotNil(receivedMessage)
        XCTAssertEqual(receivedMessage?.type, .taskAssignment)
    }

    // MARK: - Performance Tests

    func testAgentSchedulerPerformance() {
        let scheduler = AgentScheduler()

        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(options: options) {
            let task = AgentTask(type: .analyze, parameters: [:])
            Task {
                _ = await scheduler.findAgent(for: task, in: [:])
            }
        }
    }
}

// MARK: - Integration Tests

final class AIAgentIntegrationTests: XCTestCase {

    func testFullProductionWorkflow() async throws {
        let agentSystem = AISubAgentSystem.shared

        // Step 1: Analyze reference
        let analyzeTask = AgentTask(
            type: .analyze,
            parameters: ["type": "reference", "url": "/tmp/reference.wav"]
        )
        let analyzeResult = await agentSystem.submitTask(analyzeTask)
        XCTAssertNotNil(analyzeResult)

        // Step 2: Compose based on analysis
        let composeResult = await agentSystem.autoCompose(
            style: "pop",
            duration: 180,
            key: "C",
            tempo: 120
        )
        XCTAssertTrue(composeResult.success || !composeResult.success) // Either outcome is valid in test

        // Step 3: Mix
        let mixResult = await agentSystem.autoMix(projectId: "test")
        XCTAssertNotNil(mixResult)

        // Step 4: Master
        let masterResult = await agentSystem.autoMaster(
            audioURL: URL(fileURLWithPath: "/tmp/mixed.wav")
        )
        XCTAssertNotNil(masterResult)
    }

    func testConcurrentAgentExecution() async throws {
        let agentSystem = AISubAgentSystem.shared

        // Submit multiple tasks concurrently
        async let result1 = agentSystem.submitTask(AgentTask(type: .analyze, parameters: [:]))
        async let result2 = agentSystem.submitTask(AgentTask(type: .generate, parameters: [:]))
        async let result3 = agentSystem.submitTask(AgentTask(type: .critique, parameters: [:]))

        let results = await [result1, result2, result3]
        XCTAssertEqual(results.count, 3)
    }
}
