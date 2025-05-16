//
//  AudioManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 01.03.25.
//

import AVFoundation

class AudioManager {
    static var audioPlayer: AVAudioPlayer?
    
    static func playSound() {
        guard let soundURL = Bundle.main.url(forResource: "timeIsNow", withExtension: "mp3") else {
            log("Sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            log("Error playing sound: \(error.localizedDescription)")
        }
    }
}
