import os

@usableFromInline
final class Lock {

    @usableFromInline
    let _cylinder: os_unfair_lock_t

    @inlinable
    init() {
        _cylinder = .allocate(capacity: 1)
        _cylinder.initialize(to: os_unfair_lock_s())
    }

    @inlinable
    deinit {
        _cylinder.deinitialize(count: 1)
        _cylinder.deallocate()
    }

    @inlinable
    func lock() {
        os_unfair_lock_lock(_cylinder)
    }

    @inlinable
    func unlock() {
        os_unfair_lock_unlock(_cylinder)
    }
}
