//
//  IncomingFileTransmissionView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 05.10.25.
//

import SwiftUI
import AppKit


let toastViewSize = CGSize(width: 400, height: 100)

struct QuickDropToastView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var receiveModel: ReceiveModel
    public var onCancel: () -> Void = {}

    init(receiveModel: ReceiveModel,
                onCancel: @escaping () -> Void = {}) {
        self.receiveModel = receiveModel
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomLeading) {
                    Image(.quickDropIcon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(String("QuickDrop"))
                        .font(.system(size: 16, weight: .semibold))
                    Text("Receiving")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 12)
            }

            HStack() {
            
                CapsuleProgress(value: receiveModel.progress ?? 1.0)

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                        .background(
                            VisualEffectView(material: .hudWindow)
                                .clipShape(Circle())
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            VisualEffectView(material: .hudWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20)
        .frame(maxWidth: .infinity)
        .opacity(isFileTransferRestricted() ? 0 : 1)
    }
}


// NSVisualEffectView wrapper for macOS 11 compatible blur/vibrancy
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = state
        v.isEmphasized = true
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blendingMode
        v.state = state
    }
}


// Capsule-style linear progress (0...1)
struct CapsuleProgress: View {
    var value: Double
    var track = Color(NSColor.separatorColor).opacity(0.28)
    var fill  = Color(NSColor.systemBlue)

    var body: some View {
        GeometryReader { geo in
            let progress = max(0, min(1, value))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)
                Capsule() // Use a plain rectangle
                    .fill(fill)
                    .mask(
                        Capsule()
                            .frame(width: progress * geo.size.width)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    )
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.25), value: value)
    }
}


// MARK: - Preview
struct QuickDropToastView_Previews: PreviewProvider {
    struct Demo: View {
        
        @State var model = ReceiveModel()
        
        var body: some View {
            QuickDropToastView(
                receiveModel: model,
                onCancel: { }
            )
            .padding()
            .frame(width: toastViewSize.width, height: toastViewSize.height)
            .onAppear {
                model.progress = 0.01
            }
        }
    }
    static var previews: some View { Demo() }
}
