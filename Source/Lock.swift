import os

public final class Lock {

    @usableFromInline
    let _lock: os_unfair_lock_t

    @inlinable
    public init() {
        _lock = .allocate(capacity: 1)
        _lock.initialize(to: os_unfair_lock_s())
    }

    @inlinable
    deinit {
        _lock.deinitialize(count: 1)
        _lock.deallocate()
    }

    @inlinable
    public func lock() {
        os_unfair_lock_lock(_lock)
    }

    @inlinable
    public func unlock() {
        os_unfair_lock_unlock(_lock)
    }
}
