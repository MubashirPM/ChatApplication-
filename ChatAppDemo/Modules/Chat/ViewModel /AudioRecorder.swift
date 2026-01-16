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
    
    func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
            
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("voiceMessage.m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            
            print("Recording started")
            
        } catch {
            print("Failed to start recording")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        print("Recording stopped")
    }
}
