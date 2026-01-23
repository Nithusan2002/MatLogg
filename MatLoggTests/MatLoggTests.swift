//
//  MatLoggTests.swift
//  MatLoggTests
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import Testing
import Foundation
@testable import MatLogg

struct MatLoggTests {
    @Test func goalCalculatorFallsBackWhenMissingData() async throws {
        let input = GoalCalculationInput(
            weightKg: nil,
            heightCm: nil,
            ageYears: nil,
            gender: nil,
            activity: .moderat,
            intent: .maintain,
            pace: .calm
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        #expect(result.suggestedCalories == 2000)
    }
    
    @Test func goalCalculatorAdjustsForIntentAndPace() async throws {
        let input = GoalCalculationInput(
            weightKg: 80,
            heightCm: 180,
            ageYears: 30,
            gender: .mann,
            activity: .moderat,
            intent: .lose,
            pace: .standard
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        #expect(result.suggestedCalories < result.baselineCalories)
    }
    
    @Test func goalCalculatorClampsExtremes() async throws {
        let input = GoalCalculationInput(
            weightKg: 30,
            heightCm: 140,
            ageYears: 80,
            gender: .kvinne,
            activity: .lav,
            intent: .lose,
            pace: .fast
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        #expect(result.suggestedCalories >= 1200)
    }
    
    @Test func backoffRespectsBounds() async throws {
        let first = Backoff.nextDelay(attempt: 1)
        let later = Backoff.nextDelay(attempt: 6)
        #expect(first >= 10)
        #expect(later <= 6 * 60 * 60)
        #expect(later >= first)
    }
    
    @Test func inFlightResetsToPending() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let goal = Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2000,
            proteinTargetG: 150,
            carbsTargetG: 250,
            fatTargetG: 65
        )
        try await db.saveGoal(goal)
        let pending = await db.fetchPendingEvents(limit: 50)
        let target = pending.first(where: { $0.entityId == goal.id.uuidString })
        #expect(target != nil)
        guard let event = target else { return }
        await db.markEventsInFlight([event.eventId])
        await db.resetInFlightEvents()
        let pendingAfterReset = await db.fetchPendingEvents(limit: 50)
        #expect(pendingAfterReset.contains(where: { $0.eventId == event.eventId }))
    }
    
    @Test func retryBackoffSkipsUntilReady() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let goal = Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2100,
            proteinTargetG: 140,
            carbsTargetG: 260,
            fatTargetG: 70
        )
        try await db.saveGoal(goal)
        let pending = await db.fetchPendingEvents(limit: 50)
        guard let first = pending.first(where: { $0.entityId == goal.id.uuidString }) else {
            #expect(false)
            return
        }
        await db.markEventForRetry(first.eventId, error: "test", backoffSeconds: 60)
        let pendingAfter = await db.fetchPendingEvents(limit: 50)
        #expect(!pendingAfter.contains(where: { $0.eventId == first.eventId }))
    }
}
