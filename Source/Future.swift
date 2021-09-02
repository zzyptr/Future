@dynamicMemberLookup
public final class Future<V, E: Error> {

    @usableFromInline
    var lock: Lock?

    @usableFromInline
    var callbacks: [Callback]?

    @usableFromInline
    var result: Result?

    @inlinable
    init() {
        lock = Lock()
        callbacks = []
    }

    @inlinable
    init(result: Result) {
        self.result = result
    }

    @usableFromInline
    enum Result {
        case value(V)
        case error(E?)
    }

    @usableFromInline
    typealias Callback = (Result) -> Void
}

extension Future {

    @inlinable
    public convenience init(_ value: V) {
        self.init(result: .value(value))
    }

    @inlinable
    public convenience init(error: E) {
        self.init(result: .error(error))
    }
}

extension Future where E == Never {

    @inlinable
    public convenience init(_ value: V) {
        self.init(result: .value(value))
    }
}

extension Future where V == Never {

    @inlinable
    public convenience init(error: E) {
        self.init(result: .error(error))
    }
}

extension Future {

    @inlinable
    func addCallback(_ callback: @escaping Callback) {
        lock?.lock()
        defer { lock?.unlock() }
        if let result = result {
            callback(result)
        } else {
            callbacks?.append(callback)
        }
    }

    @inlinable
    func setResult(_ result: Result) {
        lock?.lock()
        guard self.result == nil else { return }
        self.result = result
        callbacks?.forEach { $0(result) }
        callbacks = nil
        lock?.unlock()
        lock = nil
    }

    @inlinable
    func setValue(_ value: V) {
        setResult(.value(value))
    }

    @inlinable
    func setError(_ error: E?) {
        setResult(.error(error))
    }
}

extension Future {

    @inlinable
    public subscript<U>(dynamicMember keyPath: KeyPath<V, U>) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case let .value(v):
                let u = v[keyPath: keyPath]
                futureU.setValue(u)
            case let .error(e):
                futureU.setError(e)
            }
        }
        return futureU
    }

    @inlinable
    public func map<U>(_ transform: @escaping (V) -> U) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case let .value(v):
                let u = transform(v)
                futureU.setValue(u)
            case let .error(e):
                futureU.setError(e)
            }
        }
        return futureU
    }

    @inlinable
    public func map<U>(_ transform: @escaping (V) throws -> U) -> Future<U, Error> {
        let futureU = Future<U, Error>()
        addCallback { result in
            switch result {
            case let .value(v):
                do {
                    let u = try transform(v)
                    futureU.setValue(u)
                } catch {
                    futureU.setError(error)
                }
            case let .error(e):
                futureU.setError(e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U, D>(_ transform: @escaping (V) -> Future<U, D>) -> Future<U, Error> {
        let futureU = Future<U, Error>()
        addCallback { result in
            switch result {
            case let .value(v):
                let future = transform(v)
                future.addCallback { result in
                    switch result {
                    case let .value(u):
                        futureU.setValue(u)
                    case let .error(e):
                        futureU.setError(e)
                    }
                }
            case let .error(e):
                futureU.setError(e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U>(_ transform: @escaping (V) -> Future<U, E>) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case let .value(v):
                let future = transform(v)
                future.addCallback(futureU.setResult)
            case let .error(e):
                futureU.setError(e)
            }
        }
        return futureU
    }

    @inlinable
    public func flatMap<U>(_ transform: @escaping (V) -> Future<U, Never>) -> Future<U, E> {
        let futureU = Future<U, E>()
        addCallback { result in
            switch result {
            case let .value(v):
                let future = transform(v)
                future.addCallback { result in
                    switch result {
                    case let .value(u):
                        futureU.setValue(u)
                    case .error:
                        futureU.setError(nil)
                    }
                }
            case let .error(e):
                futureU.setError(e)
            }
        }
        return futureU
    }

    @inlinable
    @discardableResult
    public func `do`(_ callback: @escaping (V) -> Void) -> Future {
        addCallback { result in
            guard case let .value(v) = result else { return }
            callback(v)
        }
        return self
    }

    @inlinable
    @discardableResult
    public func then(_ callback: @escaping () -> Void) -> Future {
        addCallback { _ in
            callback()
        }
        return self
    }
}

extension Future where E == Never {

    @inlinable
    public func flatMap<U, D>(_ transform: @escaping (V) -> Future<U, D>) -> Future<U, D> {
        let futureU = Future<U, D>()
        addCallback { result in
            switch result {
            case let .value(v):
                let future = transform(v)
                future.addCallback(futureU.setResult)
            case .error:
                futureU.setError(nil)
            }
        }
        return futureU
    }
}

extension Future {

    @inlinable
    public func mapError<D>(_ transform: @escaping (E) -> D) -> Future<V, D> {
        let futureV = Future<V, D>()
        addCallback { result in
            switch result {
            case let .value(v):
                futureV.setValue(v)
            case let .error(e?):
                let d = transform(e)
                futureV.setError(d)
            case .error:
                futureV.setError(nil)
            }
        }
        return futureV
    }

    @inlinable
    public func flatMapError<D>(_ transform: @escaping (E) -> Future<V, D>) -> Future<V, D> {
        let futureV = Future<V, D>()
        addCallback { result in
            switch result {
            case let .value(v):
                futureV.setValue(v)
            case let .error(e?):
                let future = transform(e)
                future.addCallback(futureV.setResult)
            case .error:
                futureV.setError(nil)
            }
        }
        return futureV
    }

    @inlinable
    @discardableResult
    public func `catch`(_ callback: @escaping (E) -> Void) -> Future<V, Never> {
        let futureV = Future<V, Never>()
        addCallback { result in
            switch result {
            case let .value(v):
                futureV.setValue(v)
            case let .error(e?):
                callback(e)
                futureV.setError(nil)
            case .error:
                futureV.setError(nil)
            }
        }
        return futureV
    }

    @inlinable
    public func recover(_ callback: @escaping (E) -> V) -> Future<V, Never> {
        let futureV = Future<V, Never>()
        addCallback { result in
            switch result {
            case let .value(v):
                futureV.setValue(v)
            case let .error(e?):
                let v = callback(e)
                futureV.setValue(v)
            case .error:
                futureV.setError(nil)
            }
        }
        return futureV
    }
}

extension Future {

    @inlinable
    public func and<U>(_ u: U) -> Future<(V, U), E> {
        return map { v in (v, u) }
    }

    @inlinable
    public func and<U, A, B>(_ u: U) -> Future<(A, B, U), E> where V == (A, B) {
        return map { v in (v.0, v.1, u) }
    }

    @inlinable
    public func and<U, D>(_ futureU: Future<U, D>) -> Future<(V, U), Error> {
        var vOrU: Any?
        let lock = Lock()
        let futureVU = Future<(V, U), Error>()
        addCallback { result in
            switch result {
            case let .value(v):
                lock.lock()
                defer { lock.unlock() }
                if let u = vOrU as? U {
                    futureVU.setValue((v, u))
                } else {
                    vOrU = v
                }
            case let .error(e):
                futureVU.setError(e)
            }
        }
        futureU.addCallback { result in
            switch result {
            case let .value(u):
                lock.lock()
                defer { lock.unlock() }
                if let v = vOrU as? V {
                    futureVU.setValue((v, u))
                } else {
                    vOrU = u
                }
            case let .error(e):
                futureVU.setError(e)
            }
        }
        return futureVU
    }

    @inlinable
    public func and<U, D, A, B>(_ futureU: Future<U, D>) -> Future<(A, B, U), Error> where V == (A, B) {
        return and(futureU).map { v, u in (v.0, v.1, u) }
    }

    @inlinable
    public func and<U>(_ futureU: Future<U, E>) -> Future<(V, U), E> {
        var vOrU: Any?
        let lock = Lock()
        let futureVU = Future<(V, U), E>()
        addCallback { result in
            switch result {
            case let .value(v):
                lock.lock()
                defer { lock.unlock() }
                if let u = vOrU as? U {
                    futureVU.setValue((v, u))
                } else {
                    vOrU = v
                }
            case let .error(e):
                futureVU.setError(e)
            }
        }
        futureU.addCallback { result in
            switch result {
            case let .value(u):
                lock.lock()
                defer { lock.unlock() }
                if let v = vOrU as? V {
                    futureVU.setValue((v, u))
                } else {
                    vOrU = u
                }
            case let .error(e):
                futureVU.setError(e)
            }
        }
        return futureVU
    }

    @inlinable
    public func and<U, A, B>(_ futureU: Future<U, E>) -> Future<(A, B, U), E> where V == (A, B) {
        return and(futureU).map { v, u in (v.0, v.1, u) }
    }

    @inlinable
    public func and<U>(_ futureU: Future<U, Never>) -> Future<(V, U), E> {
        var vOrU: Any?
        let lock = Lock()
        let futureVU = Future<(V, U), E>()
        addCallback { result in
            switch result {
            case let .value(v):
                lock.lock()
                defer { lock.unlock() }
                if let u = vOrU as? U {
                    futureVU.setValue((v, u))
                } else {
                    vOrU = v
                }
            case let .error(e):
                futureVU.setError(e)
            }
        }
        futureU.addCallback { result in
            switch result {
            case let .value(u):
                lock.lock()
                defer { lock.unlock() }
                if let v = vOrU as? V {
                    futureVU.setValue((v, u))
                } else {
                    vOrU = u
                }
            case .error:
                futureVU.setError(nil)
            }
        }
        return futureVU
    }

    @inlinable
    public func and<U, A, B>(_ futureU: Future<U, Never>) -> Future<(A, B, U), E> where V == (A, B) {
        return and(futureU).map { v, u in (v.0, v.1, u) }
    }
}

extension Future where E == Never {

    @inlinable
    public func and<U, D>(_ futureU: Future<U, D>) -> Future<(V, U), D> {
        return futureU.and(self).map { u, v in (v, u) }
    }

    @inlinable
    public func and<U, D, A, B>(_ futureU: Future<U, D>) -> Future<(A, B, U), D> where V == (A, B) {
        return futureU.and(self).map { u, v in (v.0, v.1, u) }
    }
}
