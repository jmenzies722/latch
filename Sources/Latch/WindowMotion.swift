import AppKit
import QuartzCore

@MainActor
final class WindowMotion {
    static let shared = WindowMotion()

    private struct Flight {
        var element: AXUIElement
        var from: CGRect
        var to: CGRect
    }

    private var flights: [Flight] = []
    private var started: CFTimeInterval = 0
    private var timer: Timer?
    private var finished: (() -> Void)?

    private init() {}

    var isPlaying: Bool { timer != nil }

    func play(_ moves: [(AXUIElement, CGRect)], then finished: (() -> Void)? = nil) {
        cancel()
        let prepared: [Flight] = moves.compactMap { element, to in
            let dest = WindowEngine.fitted(to)
            let from = WindowEngine.readFrame(element) ?? dest
            if hypot(dest.midX - from.midX, dest.midY - from.midY) < 3,
               abs(dest.width - from.width) < 3,
               abs(dest.height - from.height) < 3
            {
                WindowEngine.apply(dest, to: element)
                return nil
            }
            return Flight(element: element, from: from, to: dest)
        }
        guard !prepared.isEmpty else {
            finished?()
            return
        }
        self.flights = prepared
        self.finished = finished
        started = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        flights = []
        finished = nil
    }

    private func tick() {
        let t = Motion.easeOutCubic(CGFloat((CACurrentMediaTime() - started) / Motion.duration))
        let clamped = min(t, 1)
        for flight in flights {
            WindowEngine.apply(Motion.lerp(flight.from, flight.to, t: clamped), to: flight.element)
        }
        guard clamped >= 1 else { return }
        let done = finished
        cancel()
        done?()
    }
}
