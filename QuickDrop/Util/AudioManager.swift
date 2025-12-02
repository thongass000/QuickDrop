//
//  AudioManager.swift
//  QuickDrop
//
//  Created by Leon Böttger on 01.03.25.
//

import AVFoundation
import LUI

class AudioManager {
    static private var incomingFileSoundPlayer: AVAudioPlayer?
    static private var errorSoundPlayer: AVAudioPlayer?
    
    static func playIncomingFileSound() {
        guard let soundURL = Bundle.main.url(forResource: "timeIsNow", withExtension: "mp3") else {
            log("Sound file not found")
            return
        }
        
        do {
            incomingFileSoundPlayer = try AVAudioPlayer(contentsOf: soundURL)
            incomingFileSoundPlayer?.play()
        } catch {
            log("Error playing sound: \(error.localizedDescription)")
        }
    }
    
    static func playErrorSound() {
        guard let soundURL = Bundle.main.url(forResource: "justMaybe", withExtension: "mp3") else {
            log("Sound file not found")
            return
        }
        
        do {
            errorSoundPlayer = try AVAudioPlayer(contentsOf: soundURL)
            errorSoundPlayer?.play()
        } catch {
            log("Error playing sound: \(error.localizedDescription)")
        }
    }
}
