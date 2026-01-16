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
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            // Create unique filename for each recording
            let fileName = "voiceMessage_\(UUID().uuidString).m4a"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            
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
        audioRecorder?.stop()
        
        let duration: Double
        if let startTime = recordingStartTime {
            duration = Date().timeIntervalSince(startTime)
        } else {
            duration = 0
        }
        
        recordingStartTime = nil
        let url = audioURL
        audioURL = nil
        
        debugPrint("Recording stopped. Duration: \(duration) seconds")
        return (url, duration)
    }
    
    /// Cancel current recording and delete the file
    func cancelRecording() {
        audioRecorder?.stop()
        
        if let url = audioURL {
            try? FileManager.default.removeItem(at: url)
        }
        
        recordingStartTime = nil
        audioURL = nil
        debugPrint("Recording cancelled")
    }
}
