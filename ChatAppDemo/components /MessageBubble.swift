//
//  MessageBubble.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 14/01/26.
//

import SwiftUI
import AVFoundation
import Combine

struct MessageBubble: View {
    var message: Message
    var isFromCurrentUser: Bool
    @State private var showTime = false
    
    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading) {
            HStack {
                if message.messageType == .audio {
                    VoiceMessagePlayer(
                        audioURL: message.audioURL,
                        duration: message.audioDuration ?? 0,
                        isFromCurrentUser: isFromCurrentUser
                    )
                } else {
                    Text(message.text)
                        .padding()
                        .background(isFromCurrentUser ? Color("peach") : Color("Gray"))
                        .cornerRadius(30)
                }
            }
            .frame(maxWidth: 300, alignment: isFromCurrentUser ? .trailing : .leading)
            .onTapGesture {
                showTime.toggle()
            }
            
            if showTime {
                Text("\(message.timestamp.formatted(.dateTime.hour().minute()))")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .padding(isFromCurrentUser ? .trailing : .leading, 25)
            }
        }
        .frame(maxWidth: .infinity, alignment: isFromCurrentUser ? .trailing : .leading)
        .padding(.horizontal, 10)
    }
}

// MARK: - Voice Message Player

struct VoiceMessagePlayer: View {
    let audioURL: String?
    let duration: Double
    let isFromCurrentUser: Bool
    
    @StateObject private var audioPlayer = AudioPlayerManager()
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var tempAudioURL: URL?
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            Button {
                if audioPlayer.isPlaying {
                    audioPlayer.pause()
                } else {
                    // Handle base64 encoded audio or URL
                    if let urlString = audioURL {
                        var playURL: URL?
                        
                        if let url = URL(string: urlString), url.scheme != nil {
                            // It's a valid URL (from Firebase Storage)
                            playURL = url
                        } else {
                            // It's base64 encoded (current workaround)
                            playURL = getAudioURLFromBase64(base64String: urlString)
                            if playURL != nil {
                                tempAudioURL = playURL
                            }
                        }
                        
                        if let url = playURL {
                            audioPlayer.play(url: url)
                        } else {
                            debugPrint("Failed to get audio URL for playback")
                        }
                    }
                }
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            // Duration/Progress
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDuration(currentTime > 0 ? currentTime : duration))
                    .font(.caption)
                    .foregroundStyle(.white)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * (currentTime / max(duration, 1)), height: 2)
                    }
                }
                .frame(height: 2)
            }
            
            // Waveform icon (optional visual indicator)
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isFromCurrentUser ? Color("peach") : Color("Gray"))
        .cornerRadius(30)
        .onReceive(audioPlayer.$currentTime) { time in
            currentTime = time
        }
        .onReceive(audioPlayer.$isPlaying) { playing in
            isPlaying = playing
            if !playing && currentTime >= duration {
                // Reset to beginning when finished
                currentTime = 0
            }
        }
        .onDisappear {
            // Clean up temporary file when view disappears
            if let tempURL = tempAudioURL {
                try? FileManager.default.removeItem(at: tempURL)
                tempAudioURL = nil
            }
            audioPlayer.stop()
        }
    }
    
    /// Convert base64 string to temporary audio file URL
    private func getAudioURLFromBase64(base64String: String) -> URL? {
        guard let audioData = Data(base64Encoded: base64String) else {
            debugPrint("Failed to decode base64 audio data")
            return nil
        }
        
        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")
        
        do {
            try audioData.write(to: tempFile)
            debugPrint("Created temporary audio file: \(tempFile.path)")
            return tempFile
        } catch {
            debugPrint("Failed to write audio data to temporary file: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Audio Player Manager

class AudioPlayerManager: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    private var timer: Timer?
    
    func play(url: URL) {
        do {
            // Stop previous playback if any
            stop()
            
            // Configure audio session for playback
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            
            // Create and configure audio player
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // Start playback
            guard audioPlayer?.play() == true else {
                debugPrint("Failed to start audio playback")
                return
            }
            
            isPlaying = true
            
            // Start timer to update current time
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self = self, let player = self.audioPlayer else { return }
                self.currentTime = player.currentTime
            }
            
            debugPrint("Audio playback started: \(url.path)")
            
        } catch {
            debugPrint("Error playing audio: \(error.localizedDescription)")
            isPlaying = false
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
        debugPrint("Audio playback paused")
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        debugPrint("Audio playback stopped")
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
        
        // Deactivate audio session when finished
        try? AVAudioSession.sharedInstance().setActive(false)
        debugPrint("Audio playback finished successfully: \(flag)")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        debugPrint("Audio decode error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
        currentTime = 0
        timer?.invalidate()
    }
}

#Preview {
    VStack {
        MessageBubble(
            message: Message(
                id: "1234",
                text: "i have been creating swiftui application from crash and it is have fun",
                senderId: "sender",
                receiverId: "receiver",
                timestamp: Date(),
                messageType: .text
            ),
            isFromCurrentUser: true
        )
        
        MessageBubble(
            message: Message(
                id: "1235",
                text: "That's great! Keep it up!",
                senderId: "receiver",
                receiverId: "sender",
                timestamp: Date(),
                messageType: .text
            ),
            isFromCurrentUser: false
        )
        
        MessageBubble(
            message: Message(
                id: "1236",
                text: "🎤 Voice message",
                senderId: "sender",
                receiverId: "receiver",
                timestamp: Date(),
                messageType: .audio,
                audioURL: "https://example.com/audio.m4a",
                audioDuration: 15.5
            ),
            isFromCurrentUser: true
        )
    }
}
