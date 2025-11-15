import SwiftUI

// Simple UIViewRepresentable for blur (liquid glass)
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

struct SplashView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            // Soft background
            Color(.systemBackground).ignoresSafeArea()

            // Liquid glass card behind logo
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.25))
                .background(BlurView(style: .systemUltraThinMaterial))
                .frame(width: 260, height: 260)
                .scaleEffect(animate ? 1.03 : 0.95)
                .opacity(animate ? 1 : 0.9)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)

            // Logo placeholder
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.accentColor.opacity(0.8), Color.accentColor]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 120, height: 120)
                        .shadow(radius: 8)
                    Text("GYM")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                Text("Tu mejor versión empieza hoy")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .scaleEffect(animate ? 1.02 : 0.96)
            .opacity(animate ? 1 : 0.85)
        }
        .onAppear {
            // start subtle animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animate = true
            }
        }
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
