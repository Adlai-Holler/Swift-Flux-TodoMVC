//
//  Lock.swift
//  TripstrThree
//
//  Created by Adlai Holler on 1/29/16.
//  Copyright © 2016 tripstr. All rights reserved.
//

import Darwin

/**
A Swift replacement for NSLock. This is faster because it does not
use dynamic dispatch like Objective-C. The compiler may (and should)
inline these functions.
*/
final class Lock {
	private var _lock = pthread_mutex_t()

	init() {
		let result = pthread_mutex_init(&_lock, nil)
		assert(result == 0)
	}

	func lock() {
		let result = pthread_mutex_lock(&_lock)
		assert(result == 0)
	}

	func unlock() {
		let result = pthread_mutex_unlock(&_lock)
		assert(result == 0)
	}

	func withCriticalScope<Result>(@noescape block: (Void) throws -> Result) rethrows -> Result {
		lock()
		defer {
			unlock()
		}
		return try block()
	}

	deinit {
		let result = pthread_mutex_destroy(&_lock)
		assert(result == 0)
	}
}
