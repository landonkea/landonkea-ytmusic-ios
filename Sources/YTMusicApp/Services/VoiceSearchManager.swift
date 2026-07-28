import SwiftUI
import Speech

// MARK: - Voice Search Manager

/// Handles voice-to-text conversion for search.
///
/// Uses Apple's Speech framework to convert microphone audio into text
/// that can be used as a search query. The framework works offline (on-device)
/// or online (Apple's servers) depending on the language availability.
///
/// WHY A SEPARATE CLASS:
/// - Speech recognition requires permissions and setup
/// - It runs asynchronously (results come in as the user speaks)
/// - We need to manage the audio session lifecycle
class VoiceSearchManager: ObservableObject {
    
    /// The text recognized from speech. Updated in real-time as user speaks.
    @Published var recognizedText: String = ""
    
    /// Whether speech recognition is currently active
    @Published var isListening: Bool = false
    
    /// Error message if speech recognition fails
    @Published var errorMessage: String?
    
    /// The speech recognizer instance
    private let speechRecognizer = SFSpeechRecognizer()
    
    /// The current recognition request
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// The current recognition task
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// The audio engine captures microphone input
    private let audioEngine = AVAudioEngine()
    
    /// Whether speech recognition is available on this device
    var isAvailable: Bool {
        return speechRecognizer?.isAvailable ?? false
    }
    
    // MARK: - Lifecycle
    
    init() {
        // Request speech recognition authorization on startup
        requestAuthorization()
    }
    
    /// Request permission to use speech recognition.
    ///
    /// This is required by Apple's privacy policy. The user must explicitly
    /// allow the app to use the microphone and send speech data to Apple
    /// (if using server-based recognition).
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            // Must update UI on main thread
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied:
                    self.errorMessage = "Speech recognition denied. Enable it in Settings."
                case .restricted:
                    self.errorMessage = "Speech recognition restricted on this device."
                case .notDetermined:
                    print("Speech recognition not yet determined")
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Start Listening
    
    /// Start listening to microphone input and converting speech to text.
    ///
    /// Steps:
    /// 1. Stop any existing recognition task
    /// 2. Configure the audio session for recording
    /// 3. Create a recognition request
    /// 4. Attach the microphone input to the request
    /// 5. Start the recognition task
    ///
    /// Results come in via the recognitionTask callback as the user speaks.
    func startListening() {
        // Cancel any existing task first
        stopListening()
        
        // Check if recognition is available
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition not available"
            return
        }
        
        // Configure audio session for recording
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // .playAndRecord allows both recording and playback
            // .defaultToSpeaker routes audio through the speaker
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
            return
        }
        
        // Create the recognition request
        // .installedOnDeviceRecognitionRequest = prefer on-device (faster, private)
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true // Show results as user speaks
        // Use on-device recognition if available (more private)
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false // Fall back to server if needed
        }
        recognitionRequest = request
        
        // Get the input node from the audio engine
        let inputNode = audioEngine.inputNode
        
        // Install a tap on the input node to capture audio
        // This reads audio buffers from the microphone and feeds them to the recognizer
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024, // Small buffer = low latency
            format: recordingFormat
        ) { buffer, _ in
            // Append each audio buffer to the recognition request
            self.recognitionRequest?.append(buffer)
        }
        
        // Prepare and start the audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
            return
        }
        
        // Start the recognition task
        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            // Process recognition results as they come in
            if let result = result {
                // Update the recognized text on the main thread
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                }
            }
            
            // If there's an error or recognition is complete, stop
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
        
        isListening = true
    }
    
    // MARK: - Stop Listening
    
    /// Stop listening and finalize the recognition.
    ///
    /// Stops the audio engine, removes the tap, and cancels the recognition task.
    /// The final recognized text is preserved in recognizedText.
    func stopListening() {
        // Stop the audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // End the recognition request (finalizes the result)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        // Cancel the recognition task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isListening = false
    }
    
    // MARK: - Reset
    
    /// Clear the recognized text and reset the state.
    func reset() {
        recognizedText = ""
        errorMessage = nil
    }
}
