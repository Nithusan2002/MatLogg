//
//  MatLoggTests.swift
//  MatLoggTests
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import Testing
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
}
