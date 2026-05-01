import SwiftUI

struct GoalSummaryView: View {
    @Bindable var vm: OnboardingViewModel
    let onComplete: () -> Void

    @State private var showCustomize = false
    @State private var heroVisible = false
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var displayCalories: Int = 0
    @State private var ctaVisible = false
    @State private var heroPulse = false

    private var targetCalories: Int { Int(vm.calorieGoal) ?? 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero
                tdeeCard
                customizeSection
                completeButton
            }
            .padding(.bottom, 48)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { runEntrance() }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.biteOrange.opacity(0.35), .clear],
                            center: .center,
                            startRadius: 6,
                            endRadius: 80
                        )
                    )
                    .frame(width: 130, height: 130)
                    .scaleEffect(heroPulse ? 1.06 : 0.94)
                    .opacity(heroPulse ? 1 : 0.7)
                    .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: heroPulse)

                Image(systemName: "flame.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(Color.biteOrange)
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(Color.biteOrange.opacity(0.14)))
                    .overlay(Circle().strokeBorder(Color.biteOrange.opacity(0.25), lineWidth: 1))
            }
            .scaleEffect(heroVisible ? 1 : 0.6)
            .opacity(heroVisible ? 1 : 0)

            VStack(spacing: 4) {
                Text("Your plan")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.biteInk)
                Text("Calculated from your inputs.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.biteInkMuted)
            }
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 10)
        }
        .padding(.top, 20)
        .onAppear { heroPulse = true }
    }

    private var tdeeCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 4) {
                Text("\(displayCalories)")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.biteRed)
                    .contentTransition(.numericText(value: Double(displayCalories)))
                    .monospacedDigit()

                Text("kcal / day")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(0.4)
                    .foregroundStyle(.biteInkMuted)
            }

            HStack(spacing: 18) {
                macroSummary(label: "Protein", value: vm.proteinGoal, color: .biteBlue)
                macroSummary(label: "Carbs",   value: vm.carbsGoal,   color: .biteOrange)
                macroSummary(label: "Fat",     value: vm.fatGoal,     color: .biteRed)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 6)
        .padding(.horizontal, 24)
        .scaleEffect(ringScale)
        .opacity(ringOpacity)
    }

    private var customizeSection: some View {
        VStack(spacing: 14) {
            Button {
                BiteHaptics.selection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showCustomize.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(Color.bitePurple)
                    Text("Customize")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.biteInk)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.biteInkFaint)
                        .rotationEffect(.degrees(showCustomize ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)

            if showCustomize {
                VStack(spacing: 14) {
                    customizeRow(icon: "flame.fill",     label: "Calories", value: $vm.calorieGoal, unit: "kcal", color: .biteOrange)
                    Divider().padding(.horizontal, 4)
                    customizeRow(icon: "p.circle.fill",  label: "Protein",  value: $vm.proteinGoal, unit: "g",    color: .biteBlue)
                    Divider().padding(.horizontal, 4)
                    customizeRow(icon: "c.circle.fill",  label: "Carbs",    value: $vm.carbsGoal,   unit: "g",    color: .biteOrange)
                    Divider().padding(.horizontal, 4)
                    customizeRow(icon: "f.circle.fill",  label: "Fat",      value: $vm.fatGoal,     unit: "g",    color: .biteRed)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .opacity(ctaVisible ? 1 : 0)
        .offset(y: ctaVisible ? 0 : 12)
    }

    private var completeButton: some View {
        Button {
            BiteHaptics.success()
            onComplete()
        } label: {
            HStack(spacing: 8) {
                Text("Finish")
                    .font(.system(size: 16, weight: .heavy))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(PressableProminentButtonStyle(tint: .biteRed))
        .disabled(!vm.isGoalsValid)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .opacity(ctaVisible ? 1 : 0)
        .offset(y: ctaVisible ? 0 : 16)
    }

    private func macroSummary(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.4)
                .foregroundStyle(.biteInkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func customizeRow(icon: String, label: String, value: Binding<String>, unit: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.14)))

            Text(label)
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.biteInk)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", text: value)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)

                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.biteInkMuted)
            }
        }
        .padding(.vertical, 4)
    }

    private func runEntrance() {
        withAnimation(BiteMotion.onboardingHero) { heroVisible = true }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.72).delay(0.18)) {
            ringScale = 1
            ringOpacity = 1
        }
        // Animated number tick from 0 → final TDEE.
        animateNumberFromZero()
        withAnimation(BiteMotion.onboardingTitle.delay(0.55)) { ctaVisible = true }
    }

    private func animateNumberFromZero() {
        let target = targetCalories
        guard target > 0 else { displayCalories = target; return }
        displayCalories = 0
        let totalDuration: Double = 1.1
        let steps = 30
        let stepDelay = totalDuration / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30 + stepDelay * Double(i)) {
                let t = Double(i) / Double(steps)
                let eased = 1 - pow(1 - t, 3) // easeOutCubic
                withAnimation(.linear(duration: stepDelay)) {
                    displayCalories = Int(Double(target) * eased)
                }
            }
        }
    }
}

#Preview {
    GoalSummaryView(vm: OnboardingViewModel(), onComplete: {})
}
