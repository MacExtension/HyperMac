import SwiftUI

/// Thẻ điều khiển quạt kiểu iStat Menus: System Controlled / Medium / High + thanh trượt %.
struct FanControlCardView: View {
    @ObservedObject var fan: FanManager

    var body: some View {
        if fan.isAvailable {
            VStack(alignment: .leading, spacing: 7) {
                header
                modeRow
                if fan.mode == .curve { curveEditor }
                sliderRow
                statusRow
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: Rad.md, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: Rad.md).stroke(Color.primary.opacity(0.06), lineWidth: 1))
            )
            .onAppear { syncSlider() }
            .onChange(of: fan.targetRPM) { if !fan.isDragging { syncSlider() } }
            .onChange(of: fan.mode) { if !fan.isDragging { syncSlider() } }
            // Ở chế độ System, thanh trượt bám theo tốc độ quạt thực tế (như iStat Menus).
            .onChange(of: fan.currentRPM) {
                if !fan.isDragging && fan.mode == .system { syncSlider() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "fanblades.fill")
                    .font(.system(size: FS.title, weight: .bold))
                    .foregroundStyle(.secondary)
                Text(fan.fanCount > 1 ? tr("Quạt (\(fan.fanCount))", "Fans (\(fan.fanCount))") : tr("Quạt", "Fan"))
                    .font(.system(size: FS.body, weight: .bold))
                Spacer()
                Text("\(Self.fmt(fan.currentRPM)) RPM")
                    .font(.system(size: FS.body, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            rpmBar
        }
    }

    /// Thanh RPM thực tế (0 → max), như thanh quạt trong iStat Menus.
    private var rpmBar: some View {
        GeometryReader { geo in
            let ratio = fan.maxRPM > 0 ? min(max(fan.currentRPM / fan.maxRPM, 0), 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: max(ratio > 0 ? 4 : 0, geo.size.width * ratio))
                    .animation(.easeOut(duration: 0.25), value: ratio)
            }
        }
        .frame(height: 5)
        .accessibilityLabel(tr("Tốc độ quạt thực tế", "Actual fan speed"))
        .accessibilityValue("\(Self.fmt(fan.currentRPM)) RPM")
    }

    private static func fmt(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
    }

    private var modeRow: some View {
        HStack(spacing: 5) {
            modeButton(tr("Hệ thống", "System"), active: fan.mode == .system, requiresHelper: false) { fan.selectSystem() }
            modeButton("Medium", active: fan.mode == .medium) { fan.selectMedium() }
            modeButton("High", active: fan.mode == .high) { fan.selectHigh() }
            modeButton(tr("Đường cong", "Curve"), active: fan.mode == .curve) { fan.selectCurve() }
        }
    }

    private func modeButton(_ title: String, active: Bool, requiresHelper: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: requiresHelper ? handleModeTap(action) : action) {
            Text(title)
                .font(.system(size: FS.label, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: Rad.sm).fill(active ? Color.accentColor : Color.primary.opacity(0.07)))
                .foregroundStyle(active ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    /// Nếu chưa có helper thì bấm bất kỳ chế độ nào ngoài System sẽ mở cài đặt helper.
    private func handleModeTap(_ action: @escaping () -> Void) -> () -> Void {
        return {
            if !fan.isHelperReady {
                fan.installHelperIfNeeded()
            } else {
                action()
            }
        }
    }

    private var sliderRow: some View {
        VStack(spacing: 3) {
            HStack {
                Text(fan.mode == .system
                     ? tr("Tự động (hệ thống) · kéo để đặt tay", "Automatic (system) · drag to set manually")
                     : (fan.mode == .manual ? tr("Thủ công", "Manual") : tr("Tốc độ đặt", "Target speed")))
                    .font(.system(size: FS.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if fan.mode != .system || fan.isDragging {
                    Text("\(Self.fmt(fan.rpm(forPercent: fan.sliderPercent))) RPM (\(Int(fan.sliderPercent.rounded()))%)")
                        .font(.system(size: FS.label, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            Slider(
                value: $fan.sliderPercent,
                in: Double(fan.minPercent)...100,
                onEditingChanged: { editing in
                    fan.isDragging = editing
                    if !editing { commitSlider() }
                }
            )
            .controlSize(.small)
            .disabled(!fan.isHelperReady)
            .accessibilityLabel(tr("Tốc độ quạt thủ công", "Manual fan speed"))
            .accessibilityValue("\(Int(fan.sliderPercent.rounded()))%")
            HStack {
                Text("\(Self.fmt(fan.minRPM)) RPM")
                Spacer()
                Text("\(Self.fmt(fan.maxRPM)) RPM")
            }
            .font(.system(size: FS.caption))
            .foregroundStyle(.tertiary)
        }
    }

    private var curveEditor: some View {
        VStack(spacing: 5) {
            curveSensorRow
            curveGraph
            curveAxisLabels
        }
        .padding(7)
        .background(RoundedRectangle(cornerRadius: Rad.sm).fill(Color.primary.opacity(0.04)))
    }

    private var curveSensorRow: some View {
        HStack {
            Text(tr("Cảm biến", "Sensor"))
                .font(.system(size: FS.caption, weight: .medium))
            Picker("", selection: Binding(
                get: { fan.curve.sensor },
                set: { fan.curve.sensor = $0 }
            )) {
                ForEach(FanCurveSensor.allCases, id: \.self) { sensor in
                    Text(sensor.title).tag(sensor)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            Spacer()
            Button(tr("Mặc định", "Reset")) { fan.resetCurve() }
                .buttonStyle(.plain)
                .font(.system(size: FS.caption))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var curveGraph: some View {
        GeometryReader { geo in
            let width = max(CGFloat(1), geo.size.width - 18)
            let height: CGFloat = 86
            ZStack {
                curveAxes(width: width, height: height)
                curveLine(width: width, height: height)
                ForEach(fan.curve.points.indices, id: \.self) { index in
                    curvePoint(at: index, width: width, height: height)
                }
            }
            .coordinateSpace(name: "fanCurveGraph")
        }
        .frame(height: 101)
    }

    private func curveAxes(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 9, y: height + 5))
            path.addLine(to: CGPoint(x: width + 9, y: height + 5))
            path.move(to: CGPoint(x: 9, y: 5))
            path.addLine(to: CGPoint(x: 9, y: height + 5))
        }
        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
    }

    private func curveLine(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            for (index, point) in fan.curve.points.enumerated() {
                let position = curvePosition(for: point, width: width, height: height)
                if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
            }
        }
        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func curvePoint(at index: Int, width: CGFloat, height: CGFloat) -> some View {
        let point = fan.curve.points[index]
        let position = curvePosition(for: point, width: width, height: height)
        return Circle()
            .fill(Color.accentColor)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .position(position)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("fanCurveGraph")).onChanged { drag in
                let temperature = 35 + Double((drag.location.x - 9) / width * 55)
                let percent = 100 - Double((drag.location.y - 5) / height * 100)
                fan.updateCurvePoint(at: index, temperature: temperature, percent: percent)
            })
            .help("\(Int(point.temperature))°C → \(Int(point.percent))%")
    }

    private func curvePosition(for point: FanCurvePoint, width: CGFloat, height: CGFloat) -> CGPoint {
        let x = 9 + CGFloat((point.temperature - 35) / 55) * width
        let y = 5 + CGFloat((100 - point.percent) / 100) * height
        return CGPoint(x: x, y: y)
    }

    private var curveAxisLabels: some View {
        HStack {
            Text("35°C")
            Spacer()
            Text(tr("Kéo điểm để chỉnh °C và %", "Drag points to set °C and %"))
            Spacer()
            Text("90°C")
        }
        .font(.system(size: FS.caption))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var statusRow: some View {
        if let msg = fan.errorMessage {
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: FS.caption))
                .foregroundStyle(.orange)
        } else if !fan.isHelperReady {
            Button {
                fan.installHelperIfNeeded()
            } label: {
                Label(tr("Cài helper để điều khiển quạt (hỏi mật khẩu 1 lần)",
                         "Install helper to control the fan (asks password once)"),
                      systemImage: "lock.shield")
                    .font(.system(size: FS.caption, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        } else if fan.safetyTripped {
            Label(tr("Quá nóng: quạt do hệ thống điều khiển.", "Too hot: fan under system control."),
                  systemImage: "flame.fill")
                .font(.system(size: FS.caption))
                .foregroundStyle(.red)
        }
    }

    private func syncSlider() {
        if fan.mode == .system || fan.targetRPM <= 0 {
            fan.sliderPercent = max(Double(fan.minPercent), Double(fan.percent(forRPM: fan.currentRPM)))
        } else {
            fan.sliderPercent = Double(fan.percent(forRPM: fan.targetRPM))
        }
    }

    private func commitSlider() {
        guard fan.isHelperReady else { return }
        fan.setManual(rpm: fan.rpm(forPercent: fan.sliderPercent))
    }
}
