//
//  PieProgressView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 16.08.25.
//

import SwiftUI

struct PieProgressView: View {
    let progress: CGFloat // value between 0.0 and 1.0
    var size: CGFloat = 25.0
    
    var color: Color? = nil
    
    var body: some View {
        
        let color = color ?? .gray
        
        ZStack {
              
            Circle()
                .stroke(lineWidth: size * 0.08)
                .foregroundColor(color)
            
            ZStack {
                PieSlice(progress: progress)
                    .fill(color)
                    .rotationEffect(.degrees(-90)) // Start from the top
            }
            .overlay (
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color == .white ? .blue : .white)
                    .opacity(progress >= 1.0 ? 1.0 : 0.0) // Show checkmark only when complete
            )
        }
        .frame(width: size, height: size)
    }
}


struct PieSlice: Shape {
    var progress: CGFloat // from 0.0 to 1.0
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        let endAngle = Angle(degrees: 360 * Double(progress))
        
        path.move(to: center)
        path.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(0),
                    endAngle: endAngle,
                    clockwise: false)
        path.closeSubpath()
        
        return path
    }
}


#Preview {
    PieProgressView(progress: 0.76)
        .padding()
}
