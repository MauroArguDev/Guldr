//
//  MotionTests.swift
//  GuldrTests
//
//  Created by Mauricio Argumedo on 10/10/26.
//

import SwiftUI
import Testing
@testable import Guldr

/// The Reduce Motion rules from DESIGN.md › Motion.
struct MotionTests {

    @Test func tokensMatchTheSpec() {
        #expect(Motion.standard.animation == .smooth(duration: 0.35))
        #expect(Motion.snappy.animation == .snappy(duration: 0.25))
        #expect(Motion.emphasized.animation == .spring(duration: 0.45, bounce: 0.15))
        #expect(Motion.reveal.animation == .smooth(duration: 0.6))
    }

    @Test func reduceMotionSkipsFillsAndCrossFadesTheRest() {
        #expect(Motion.reveal.resolved(reduceMotion: true) == nil)
        for motion in [Motion.standard, .snappy, .emphasized] {
            #expect(motion.resolved(reduceMotion: true) == Motion.crossFade)
            #expect(motion.resolved(reduceMotion: false) == motion.animation)
        }
    }

    @Test func staggerIsCappedAndOffWithReduceMotion() {
        #expect(Motion.staggerDelay(index: 0, reduceMotion: false) == 0)
        #expect(abs(Motion.staggerDelay(index: 3, reduceMotion: false) - 0.12) < 0.0001)
        #expect(Motion.staggerDelay(index: 100, reduceMotion: false) == Motion.staggerMaxTotal)
        #expect(Motion.staggerDelay(index: -1, reduceMotion: false) == 0)
        #expect(Motion.staggerDelay(index: 5, reduceMotion: true) == 0)
    }
}
