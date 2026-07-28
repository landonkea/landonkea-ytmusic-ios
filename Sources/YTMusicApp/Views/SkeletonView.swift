// Import Apple's SwiftUI framework — provides View, Color, Rectangle,
// GeometryReader, Animation, and all other UI tools used here
import SwiftUI

// MARK: - Skeleton View

/// A placeholder view with a shimmer animation for loading states.
///
/// Shows a gray rectangle with a moving gradient that creates a "shimmer" effect.
/// Used to indicate content is loading, giving the user visual feedback that
/// something is happening (better than a blank screen or spinner).
struct SkeletonView: View {
    
    /// The width of the skeleton element in points (e.g. 100 for a 100pt-wide placeholder)
    let width: CGFloat
    
    /// The height of the skeleton element in points (e.g. 100 for a 100pt-tall placeholder)
    let height: CGFloat
    
    /// Corner radius for rounded corners — makes the skeleton look softer by default (8pt)
    let cornerRadius: CGFloat
    
    /// The current phase of the shimmer animation (0.0 to 1.0)
    /// Starts at 0 and animates to 1.0, making the highlight slide across the view
    @State private var phase: CGFloat = 0
    
    /// Creates a skeleton loading placeholder with a shimmer animation
    /// - Parameters:
    ///   - width: The width of the skeleton placeholder
    ///   - height: The height of the skeleton placeholder
    ///   - cornerRadius: How rounded the corners should be (defaults to 8 points)
    init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    /// The body of the skeleton view — draws the shimmering rectangle
    var body: some View {
        // GeometryReader gives us access to the view's size and position
        GeometryReader { geometry in
            // The base shape — a simple filled rectangle
            Rectangle()
                // Fills the rectangle with a gradient that creates the shimmer effect
                // The gradient moves from light gray → slightly lighter → light gray
                .fill(
                    // LinearGradient creates the shimmer effect
                    // The gradient moves from light gray (30%) → lighter (50%) → light gray (30%)
                    LinearGradient(
                        // Defines the gradient with three color stops
                        gradient: Gradient(
                            colors: [
                                // Darker gray at the start (30% opacity)
                                Color.gray.opacity(0.3),
                                // Brighter gray in the middle (50% opacity) — the "shimmer" peak
                                Color.gray.opacity(0.5),
                                // Darker gray at the end (30% opacity)
                                Color.gray.opacity(0.3)
                            ]
                        ),
                        // Gradient starts from the left edge
                        startPoint: .leading,
                        // Gradient ends at the right edge
                        endPoint: .trailing
                    )
                )
                // Apply an overlay that creates the moving highlight
                .overlay(
                    // Another GeometryReader to calculate positions relative to this rectangle
                    GeometryReader { proxy in
                        // The highlight rectangle moves from left to right
                        Rectangle()
                            // Fills the highlight with a transparent → white → transparent gradient
                            .fill(
                                LinearGradient(
                                    // Three stops: clear on both ends, white (30%) in the middle
                                    gradient: Gradient(
                                        colors: [
                                            // Fully transparent on the left edge of the highlight
                                            .clear,
                                            // White with 30% opacity in the center of the highlight
                                            .white.opacity(0.3),
                                            // Fully transparent on the right edge of the highlight
                                            .clear
                                        ]
                                    ),
                                    // Highlight gradient also goes left-to-right
                                    startPoint: .leading,
                                    // To match the base gradient direction
                                    endPoint: .trailing
                                )
                            )
                            // The highlight is half the width of the parent rectangle
                            .frame(width: proxy.size.width * 0.5)
                            // Offsets the highlight horizontally based on the animation phase
                            // When phase=0, offset = -0.5 * width (hidden off the left edge)
                            // When phase=1, offset = +0.5 * width (hidden off the right edge)
                            .offset(x: proxy.size.width * (phase - 0.5))
                    }
                )
                // Applies rounded corners to both the base and the overlay together
                .cornerRadius(cornerRadius)
        }
        // Constrains the entire GeometryReader to the requested width and height
        .frame(width: width, height: height)
        // Triggers the shimmer animation when this view first appears on screen
        .onAppear {
            // Start the shimmer animation when the view appears
            // Wraps the phase change in an animation block so it animates smoothly
            withAnimation(
                Animation
                    // Uses ease-in-out timing — starts slow, speeds up, ends slow
                    .easeInOut(duration: 1.5)
                    // Repeats forever without reversing (loops back to start instantly)
                    .repeatForever(autoreverses: false)
            ) {
                // Animates phase from 0.0 to 1.0, sliding the highlight across
                phase = 1.0
            }
        }
    }
}

// MARK: - Skeleton View Modifier

/// A view modifier that shows a skeleton while loading, then reveals the real content.
///
/// Usage: `.skeleton(isLoading: isLoading, width: 100, height: 100)`
/// When isLoading is true, the original view is hidden and a skeleton shows instead.
/// When isLoading is false, the original content is displayed normally.
struct SkeletonModifier: ViewModifier {
    
    /// Whether the skeleton is currently showing
    /// When true, displays the shimmer placeholder. When false, shows the real content.
    let isLoading: Bool
    
    /// Width of the skeleton placeholder in points
    let width: CGFloat
    
    /// Height of the skeleton placeholder in points
    let height: CGFloat
    
    /// Applies the modifier to the content — replaces with skeleton or shows the real content
    /// - Parameter content: The original view that this modifier is applied to
    /// - Returns: Either a SkeletonView or the original content
    func body(content: Content) -> some View {
        // If loading, show the shimmer placeholder instead of the real content
        if isLoading {
            SkeletonView(width: width, height: height)
        } else {
            // Otherwise, show the original content as-is
            content
        }
    }
}

// Extends the View protocol so every view gets the .skeleton() modifier
extension View {
    /// Show a skeleton placeholder while content is loading.
    /// - Parameters:
    ///   - isLoading: When true, shows skeleton; when false, shows the original content
    ///   - width: Width of the skeleton placeholder
    ///   - height: Height of the skeleton placeholder
    /// - Returns: A view that conditionally shows skeleton or original content
    func skeleton(isLoading: Bool, width: CGFloat, height: CGFloat) -> some View {
        // Applies the SkeletonModifier to this view using the modifier() method
        modifier(SkeletonModifier(isLoading: isLoading, width: width, height: height))
    }
}

// MARK: - Skeleton Section (Home Page)

/// A skeleton placeholder for a home page section (horizontal carousel).
///
/// Shows 3-4 gray rectangles that look like song cards loading.
/// Used in HomeView while the API is fetching data.
/// Mimics the layout of the real content so the user knows what to expect.
struct SkeletonSection: View {
    /// The body of the skeleton section — a vertical stack with header + horizontal cards
    var body: some View {
        // A vertical stack aligned to the left with 12pt spacing
        VStack(alignment: .leading, spacing: 12) {
            // Section header skeleton — a short wide rectangle for the section title
            SkeletonView(width: 150, height: 20, cornerRadius: 4)
                // Adds horizontal padding to match the real content's layout
                .padding(.horizontal)
            
            // Horizontal row of card skeletons — scrollable like the real content
            ScrollView(.horizontal, showsIndicators: false) {
                // A horizontal stack with 12pt spacing between cards
                HStack(spacing: 12) {
                    // Creates 4 identical card skeletons using a ForEach loop
                    ForEach(0..<4, id: \.self) { _ in
                        // Each card is a vertical stack with album art, title, and artist
                        VStack(alignment: .leading, spacing: 6) {
                            // Album art skeleton — a square placeholder (120x120)
                            SkeletonView(width: 120, height: 120, cornerRadius: 8)
                            // Title skeleton — a wide thin rectangle for the song name
                            SkeletonView(width: 100, height: 12, cornerRadius: 4)
                            // Artist skeleton — a narrower thin rectangle for the artist name
                            SkeletonView(width: 80, height: 10, cornerRadius: 4)
                        }
                    }
                }
                // Adds horizontal padding to the entire row of cards
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Preview

/// A preview provider for Xcode's Canvas — shows what skeleton views look like at design time
#Preview {
    // A vertical stack showing the two skeleton types side-by-side
    VStack(spacing: 20) {
        // A single square skeleton placeholder (100x100)
        SkeletonView(width: 100, height: 100)
        // A full home page section skeleton with header and horizontal cards
        SkeletonSection()
    }
    // Adds padding around the entire preview
    .padding()
}
