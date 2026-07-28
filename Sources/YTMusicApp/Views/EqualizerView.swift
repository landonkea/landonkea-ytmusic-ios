// EqualizerView.swift — The equalizer screen where users can adjust audio frequencies and apply presets.

import SwiftUI

/// The equalizer screen where users adjust audio frequencies and select presets.
///
/// Shows a scrollable list of frequency band sliders and a grid of preset buttons.
/// Each slider controls one frequency band (32Hz to 16KHz).
/// Presets apply pre-configured settings for common listening scenarios.
struct EqualizerView: View {
    
    /// The equalizer manager — handles audio processing and settings
    @EnvironmentObject var equalizer: EqualizerManager
    
    /// Dismiss this modal
    @Environment(\.dismiss) var dismiss
    
    /// The main view content — describes what appears on screen and how it's laid out
    var body: some View {
        NavigationView { // Embeds content in a navigation controller with title bar
            ScrollView { // Makes all content scrollable if it exceeds screen height
                VStack(spacing: 24) {
                    // ── POWER TOGGLE ──────────────────────────────────
                    // Master on/off switch for the equalizer
                    HStack {
                        // "Equalizer" title label
                        Text("Equalizer")
                            .font(.title2) // Slightly smaller than title
                            .fontWeight(.bold) // Bold text
                        
                        Spacer() // Push toggle to the right
                        
                        // Toggle switch — green when on, gray when off
                        Toggle("", isOn: Binding(
                            // Read current enabled state from manager
                            get: { equalizer.isEnabled },
                            // When toggled, call the manager's toggle method
                            set: { _ in equalizer.toggle() }
                        ))
                        .labelsHidden() // Hide the empty label so no extra space appears
                    }
                    .padding(.horizontal) // Side padding
                    
                    // ── ACTIVE PRESET DISPLAY ─────────────────────────
                    // Shows which preset is currently active
                    HStack {
                        // "Active:" label
                        Text("Active:")
                            .font(.subheadline) // Small font
                            .foregroundColor(.secondary) // Gray secondary color
                        
                        // Name of the active preset
                        Text(equalizer.activePreset)
                            .font(.subheadline) // Small font
                            .fontWeight(.medium) // Medium weight (not bold, not light)
                            .foregroundColor(.blue) // Blue text to make it stand out
                        
                        Spacer() // Push content to the left
                    }
                    .padding(.horizontal) // Side padding
                    
                    // ── FREQUENCY BAND SLIDERS ────────────────────────
                    // 10 vertical sliders, one per frequency band
                    // Each slider goes from -12dB to +12dB
                    VStack(spacing: 8) {
                        // Section header
                        Text("Frequency Bands")
                            .font(.headline) // Bold section header
                            .frame(maxWidth: .infinity, alignment: .leading) // Stretch left
                        
                        // Horizontal scroll of vertical sliders
                        ScrollView(.horizontal, showsIndicators: false) { // No scroll bar
                            HStack(spacing: 16) { // Horizontal row of band sliders
                                // Loop through bands 0 through 9 (10 total)
                                ForEach(0..<10, id: \.self) { band in
                                    VStack(spacing: 8) {
                                        // Gain value display (e.g. "+4 dB")
                                        Text("\(Int(equalizer.bandGains[band]))dB")
                                            .font(.caption2) // Very small font
                                            .foregroundColor(.secondary) // Gray color
                                            .frame(width: 40) // Fixed width for alignment
                                        
                                        // Vertical slider for this band
                                        // Rotation effect makes it vertical (bottom to top)
                                        VStack {
                                            Slider(
                                                value: Binding(
                                                    // Read current gain for this band
                                                    get: { equalizer.bandGains[band] },
                                                    // Update gain in the manager when user drags
                                                    set: { newValue in
                                                        equalizer.setBand(band, gain: newValue)
                                                    }
                                                ),
                                                in: -12...12, // Range: -12dB to +12dB
                                                step: 1 // Snap to whole decibel values
                                            )
                                            .rotationEffect(.degrees(-90)) // Rotate horizontal slider to vertical
                                            .frame(width: 120) // Width becomes height after rotation
                                        }
                                        .frame(height: 160) // Actual visible height of the slider
                                        
                                        // Frequency label (e.g. "1K", "4K")
                                        Text(EqualizerManager.bandLabels[band])
                                            .font(.caption2) // Very small font
                                            .foregroundColor(.secondary) // Gray color
                                    }
                                }
                            }
                            .padding(.horizontal, 4) // Minimal side padding for the scroll
                        }
                    }
                    .padding(.horizontal) // Side padding
                    
                    // ── PRESET BUTTONS ────────────────────────────────
                    // Grid of preset buttons for quick EQ settings
                    VStack(spacing: 12) {
                        // Section header
                        Text("Presets")
                            .font(.headline) // Bold section header
                            .frame(maxWidth: .infinity, alignment: .leading) // Stretch left
                        
                        // LazyVGrid creates a responsive grid
                        // .flexible() = columns adapt to screen width
                        // 3 columns = 3 buttons per row
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible()), // Column 1 — flexible width
                                GridItem(.flexible()), // Column 2 — flexible width
                                GridItem(.flexible())  // Column 3 — flexible width
                            ],
                            spacing: 10 // Vertical spacing between rows
                        ) {
                            // "Custom" preset (only shown when user manually adjusts bands)
                            if equalizer.activePreset == "Custom" {
                                PresetButton(
                                    name: "Custom", // Preset name
                                    isActive: equalizer.activePreset == "Custom", // True = currently active
                                    action: {} // No action needed — already on Custom
                                )
                            }
                            
                            // All built-in presets from the EqualizerManager presets dictionary
                            ForEach(Array(EqualizerManager.presets.keys.sorted()), id: \.self) { name in
                                PresetButton(
                                    name: name, // Preset name (e.g. "Bass Boost")
                                    isActive: equalizer.activePreset == name, // Highlight if active
                                    action: {
                                        equalizer.applyPreset(name) // Apply the selected preset
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal) // Side padding
                }
                .padding(.vertical) // Top and bottom padding for the entire stack
            }
            .navigationTitle("Equalizer") // Title displayed in the navigation bar
            .navigationBarTitleDisplayMode(.inline) // Compact title (not large)
            .toolbar {
                // Done button in the top-right corner
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss() // Close the equalizer view
                    }
                }
            }
        }
    }
}

// MARK: - Preset Button

/// A single preset button in the equalizer grid.
///
/// Shows the preset name with a highlight when active.
/// Tapping it applies that preset to all frequency bands.
struct PresetButton: View {
    
    /// The preset name (e.g. "Bass Boost", "Rock")
    let name: String
    
    /// Whether this preset is currently active
    let isActive: Bool
    
    /// Called when the button is tapped
    let action: () -> Void
    
    /// The button's appearance and behavior
    var body: some View {
        Button(action: action) { // When tapped, run the provided action
            Text(name) // Display the preset name
                .font(.subheadline) // Small font
                .fontWeight(isActive ? .bold : .regular) // Bold when active, normal otherwise
                .frame(maxWidth: .infinity) // Stretch to fill available width
                .padding(.vertical, 10) // Top and bottom padding inside the button
                // Blue background when active, gray when not
                .background(isActive ? Color.blue : Color(.systemGray5))
                .foregroundColor(isActive ? .white : .primary) // White text on blue, dark on gray
                .cornerRadius(10) // Rounded corners
        }
        .buttonStyle(.plain) // Prevents default button styling (blue tint, etc.)
    }
}

#Preview {
    EqualizerView()
        .environmentObject(EqualizerManager()) // Provide a mock EqualizerManager for preview
}
