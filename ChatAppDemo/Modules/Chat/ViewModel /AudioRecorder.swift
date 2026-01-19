//
//  AudioRecorder.swift
//  ChatAppDemo
//
//  Created by Mubashir PM on 16/01/26.
//

import Combine
import Foundation
import AVFoundation

class AudioRecorder: NSObject, ObservableObject {
    
    var audioRecorder: AVAudioRecorder?
    private var recordingStartTime: Date?
    private var audioURL: URL?
    
    /// Start recording audio
    /// - Returns: The URL where the audio will be saved
    func startRecording() -> URL? {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure audio session for recording
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Request microphone permission if needed
            if audioSession.recordPermission == .undetermined {
                audioSession.requestRecordPermission { granted in
                    if !granted {
                        debugPrint("Microphone permission denied")
                    }
                }
            }
            
            // Create unique filename for each recording
            let fileName = "voiceMessage_\(UUID().uuidString).m4a"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0, // Higher quality sample rate
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000 // Higher bitrate for better quality
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
            
            guard audioRecorder?.record() == true else {
                debugPrint("Failed to start recording")
                return nil
            }
            
            recordingStartTime = Date()
            audioURL = url
            
            debugPrint("Recording started at: \(url.path)")
            return url
            
        } catch {
            debugPrint("Failed to start recording: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Stop recording and get the audio file URL and duration
    /// - Returns: Tuple containing audio URL and duration in seconds
    func stopRecording() -> (url: URL?, duration: Double) {
        guard let recorder = audioRecorder else {
            debugPrint("No active recording to stop")
            return (nil, 0)
        }
        
        recorder.stop()
        
        // Get actual duration from recorder if available
        let duration: Double
        if recorder.isRecording {
            // Use recorder's current time if available
            duration = recorder.currentTime
        } else if let startTime = recordingStartTime {
            duration = Date().timeIntervalSince(startTime)
        } else {
            duration = 0
        }
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        recordingStartTime = nil
        let url = audioURL
        audioURL = nil
        
        debugPrint("Recording stopped. Duration: \(duration) seconds. File: \(url?.path ?? "nil")")
        return (url, duration)
    }
    
    /// Cancel current recording and delete the file
    func cancelRecording() {
        audioRecorder?.stop()
        
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
            debugPrint("Recording file deleted: \(url.path)")
        }
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        recordingStartTime = nil
        audioURL = nil
        debugPrint("Recording cancelled")
    }
}
