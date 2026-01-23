//
//  IncomingFileTransmissionView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 05.10.25.
//

import AppKit
import LUI
import SwiftUI

let toastViewSize = CGSize(width: 400, height: 120)

struct QuickDropToastView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var receiveModel: ReceiveModel
    
    @State var autoHider = DispatchWorkItem(block: {})

    /// Cancel while receiving.
    public var onCancel: () -> Void

    init(
        receiveModel: ReceiveModel,
        onCancel: @escaping () -> Void = {}
    ) {
        self.receiveModel = receiveModel
        self.onCancel = onCancel
    }

    public var body: some View {
        
        let isDone = receiveModel.toastActions != nil
        
        VStack(spacing: 12) {
            HStack(spacing: 10) {
            
                let iconSize = 39.0
                
                AppIconView(hasPlusIcon: false, size: iconSize)
                    .frame(width: iconSize, height: iconSize)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String("QuickDrop"))
                        .font(.system(size: 16, weight: .semibold))

                    Text(isDone ? "FileTransferCompleted" : "Receiving")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 12)
            }

            ZStack {
                
                QuickDropToastViewButton(title: "OpenInFinder") { }
                .opacity(0)
                
                if let actions = receiveModel.toastActions {
                    HStack(spacing: 8) {
   
                        QuickDropToastViewButton(title: "OpenInFinder") {
                            actions.openFilesAction()
                            actions.closeToastAction()
                        }

                        if let onImportToPhotos = actions.importPhotosAction {
                            QuickDropToastViewButton(title: "ImportToPhotos") {
                                onImportToPhotos()
                                actions.closeToastAction()
                            }
                        }
                        
                        Spacer()
                        
                        QuickDropToastViewButton(title: "Done", action: actions.closeToastAction)
                            .onAppear {
                                self.autoHider = DispatchWorkItem(block: {
                                    actions.closeToastAction()
                                })
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: self.autoHider)
                            }
                            .onDisappear {
                                self.autoHider.cancel()
                            }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                HStack {
                    ZStack {
                        CapsuleProgress(value: 0.5)
                            .opacity(0)
                        
                        if let progress = receiveModel.progress {
                            CapsuleProgress(value: progress)
                        }
                    }
                    .animation(.easeInOut, value: receiveModel.progress == nil)
                    
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .opacity(isDone ? 0 : 1)
            }
        }
        .padding(16)
        .background(
            VisualEffectView(material: .hudWindow)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.03), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 20)
        .frame(maxWidth: .infinity)
    }
}


fileprivate struct QuickDropToastViewButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.localized())
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Color.gray.opacity(0.15)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)  // prevents blue macOS button look
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
                Capsule()
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
        @State var model = ReceiveModel(controlPlusScreen: { _ in })
        @State var done = true

        var body: some View {
            QuickDropToastView(
                receiveModel: model,
                onCancel: { }
            )
            .frame(width: toastViewSize.width, height: toastViewSize.height)
            .clipped()
            .padding(100)
            .background(Color.black.opacity(0.2))
            .onAppear {
                model.progress = 1
                model.toastActions = .init(openFilesAction: {}, importPhotosAction: {}, closeToastAction: {})
            }
        }
    }

    static var previews: some View { Demo() }
}
