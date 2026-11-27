import Foundation

enum FanCurveSensor: String, Codable, CaseIterable {
    case hottest, cpu, gpu, hotspot

    var title: String {
        switch self {
        case .hottest: return tr("Nóng nhất", "Hottest")
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .hotspot: return "Hotspot"
        }
    }
}

struct FanCurvePoint: Codable, Equatable {
    var temperature: Double
    var percent: Double
}

struct FanCurve: Codable, Equatable {
    var sensor: FanCurveSensor = .hottest
    var points: [FanCurvePoint] = [
        .init(temperature: 40, percent: 25),
        .init(temperature: 55, percent: 40),
        .init(temperature: 70, percent: 60),
        .init(temperature: 80, percent: 80),
        .init(temperature: 90, percent: 100)
    ]

    func percent(at temperature: Double) -> Double {
        let sorted = points.sorted { $0.temperature < $1.temperature }
        guard let first = sorted.first else { return 50 }
        if temperature <= first.temperature { return first.percent }
        for pair in zip(sorted, sorted.dropFirst()) {
            if temperature <= pair.1.temperature {
                let span = max(1, pair.1.temperature - pair.0.temperature)
                let fraction = (temperature - pair.0.temperature) / span
                return min(100, max(0, pair.0.percent + (pair.1.percent - pair.0.percent) * fraction))
            }
        }
        return min(100, max(0, sorted.last?.percent ?? 100))
    }

    mutating func movePoint(at index: Int, temperature: Double, percent: Double) {
        guard points.indices.contains(index) else { return }
        let lower = index == 0 ? 35 : points[index - 1].temperature + 2
        let upper = index == points.count - 1 ? 90 : points[index + 1].temperature - 2
        points[index].temperature = min(max(temperature.rounded(), lower), upper)
        points[index].percent = min(max(percent.rounded(), 0), 100)
    }
}
