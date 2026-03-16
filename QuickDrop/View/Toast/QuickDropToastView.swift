//
//  IncomingFileTransmissionView.swift
//  QuickDrop
//
//  Created by Leon Böttger on 05.10.25.
//

import AppKit
import LUI
import SwiftUI

let toastViewSize = CGSize(width: 340, height: 65)
let toastCornerRadius: CGFloat = 22
let toastTrailingPadding: CGFloat = 20
let toastSlideDistance: CGFloat = 420

struct QuickDropToastView: View {
    @ObservedObject var settings = Settings.sharedInstance
    @ObservedObject var receiveModel: ReceiveModel
    
    @Environment(\.colorScheme) var colorScheme
    
    @State var autoHider = DispatchWorkItem(block: {})
    @State private var isHovering = false

    /// Cancel while receiving.
    public var onCancel: () -> Void

    init(
        receiveModel: ReceiveModel,
        onCancel: @escaping () -> Void = {}
    ) {
        self.receiveModel = receiveModel
        self.onCancel = onCancel
    }

    private func startAutoHide(_ actions: ReceiveModel.ToastViewAction) {
        autoHider.cancel()
        autoHider = DispatchWorkItem(block: {
            actions.autoHideAction()
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + actions.autoHideDelay, execute: autoHider)
    }

    private func startAutoHideIfPossible() {
        guard !isHovering, let actions = receiveModel.toastActions else { return }
        startAutoHide(actions)
    }

    public var body: some View {
        
        let consent = receiveModel.consentState
        let actions = receiveModel.toastActions
        let hasActionButtons = actions?.openFilesAction != nil || actions?.importPhotosAction != nil
        let deviceName = receiveModel.activeDeviceName ?? "AndroidDevice".localized()
        let isNotificationSyncToast = consent?.notificationSyncStage != nil
        let isNotificationSyncConsent = consent?.notificationSyncStage == .consent
        let isNotificationSyncPinStage = consent?.notificationSyncStage == .pin
        let showConsentActions = consent != nil && (!isNotificationSyncToast || isNotificationSyncConsent)
        let showsRightColumn = showConsentActions || hasActionButtons
        
        let subHeaderSize = 21.0

        let closeButtonVisible = isHovering && (actions != nil || isNotificationSyncPinStage)
        
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {

                        let iconSize = 32.0
                        
                        let headerFont = Font.system(.body).bold()
                        let subheaderFont = Font.system(.body)
                        let subheaderColor = Color.secondary

                        AppIconView(hasPlusIcon: false, size: iconSize, supportsDarkModeShadow: false)
                            .frame(width: iconSize, height: iconSize)

                        VStack(alignment: .leading, spacing: 1) {
                            if let consent = consent {
                                if isNotificationSyncToast {
                                    HStack {
                                        Text(String("QuickDrop"))
                                            .font(headerFont)
                                            .lineLimit(1)
                                        
                                        Text("FromDevice".localized(with: deviceName))
                                            .font(subheaderFont)
                                            .foregroundColor(subheaderColor)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    
                                    Text(consent.message)
                                        .font(subheaderFont)
                                        .foregroundColor(subheaderColor)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                } else {
                                    Text(verbatim: "QuickDrop | \(consent.pinCodeMessage)")
                                        .font(headerFont)
                                        .lineLimit(1)
                                    
                                    Text(consent.message)
                                        .font(subheaderFont)
                                        .foregroundColor(subheaderColor)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                }
                            } else {
                                HStack {
                                    Text(String("QuickDrop"))
                                        .font(headerFont)
                                        .lineLimit(1)
                                    
                                    if consent == nil, actions == nil {
                                        Text("FromDevice".localized(with: deviceName))
                                            .font(subheaderFont)
                                            .foregroundColor(subheaderColor)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                }
                                
                                if consent == nil, actions == nil {
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
                                    .padding(.trailing, 16)
                                    .frame(height: subHeaderSize)
                                }
                                else {
                                    
                                    Text(LocalizedStringKey(actions?.completionMessageKey ?? "FileTransferCompleted"))
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(height: subHeaderSize)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                if showsRightColumn {
                    ActionColumn() {
                        if showConsentActions, let consent = consent {
                            ActionButtonRow {
                                QuickDropToastViewButton(title: "Decline") {
                                    consent.declineAction()
                                }
                            }

                            ActionButtonRow {
                                if consent.allowsTrust {
                                    QuickDropToastViewMenuButton(title: "Accept") {
                                        Button("AcceptOnce".localized()) {
                                            consent.acceptAction(false)
                                        }
                                        Button("AutoAcceptFromThisDevice".localized()) {
                                            consent.acceptAction(true)
                                        }
                                    }
                                } else {
                                    QuickDropToastViewButton(title: "Accept") {
                                        consent.acceptAction(false)
                                    }
                                }
                            }
                        } else if let actions = actions {
                            if let openFilesAction = actions.openFilesAction {
                                ActionButtonRow {
                                    QuickDropToastViewButton(title: "OpenInFinder") {
                                        openFilesAction()
                                        actions.closeToastAction()
                                    }
                                }
                            }

                            if let onImportToPhotos = actions.importPhotosAction {

                                ActionButtonRow {
                                    QuickDropToastViewButton(title: "ImportToPhotos") {
                                        onImportToPhotos()
                                        actions.closeToastAction()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.leading, 16)
        .frame(width: toastViewSize.width, height: toastViewSize.height)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }

            if hovering {
                autoHider.cancel()
            } else {
                startAutoHideIfPossible()
            }
        }
        .onChange(of: receiveModel.toastActions != nil) { hasActions in
            if hasActions {
                startAutoHideIfPossible()
            } else {
                autoHider.cancel()
            }
        }
        .onAppear {
            startAutoHideIfPossible()
        }
        .background(
            AdaptiveToastBackgroundLayer(cornerRadius: toastCornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: toastCornerRadius, style: .continuous)
                .stroke((colorScheme.isLight ? Color.white.opacity(0.5) : Color.gray.opacity(0.33)), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if closeButtonVisible {
                Button(action: {
                    if let actions = actions {
                        actions.closeToastAction()
                    } else if isNotificationSyncPinStage {
                        receiveModel.hideQuickDropToast(style: .fade)
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle()
                                .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    if hovering {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovering = true
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .shadow(color: Color.black.opacity(colorScheme.isLight ? 0.16 : 0.30), radius: 10, x: 0, y: 5)
        .shadow(color: Color.black.opacity(colorScheme.isLight ? 0.06 : 0.14), radius: 2, x: 0, y: 1)
        .frame(maxWidth: .infinity)
    }
}


struct QuickDropToastHostView: View {
    @ObservedObject var receiveModel: ReceiveModel
    let onCancel: () -> Void

    @State private var didRenderOnce = false

    private let slideAnimation = Animation.smooth
    private let fadeAnimation = Animation.easeInOut

    var body: some View {
        let isVisible = didRenderOnce && receiveModel.toastIsVisible
        let isSlide = receiveModel.toastDismissStyle == .slide
        let hiddenOffset: CGFloat = isSlide ? toastSlideDistance : 0
        let hiddenOpacity: Double = isSlide ? 1 : 0
        let hiddenBlur: CGFloat = isSlide ? 0 : 8
        let animation = isSlide ? slideAnimation : fadeAnimation

        QuickDropToastView(receiveModel: receiveModel, onCancel: onCancel)
            .frame(width: toastViewSize.width, height: toastViewSize.height)
            .offset(x: isVisible ? 0 : hiddenOffset)
            .opacity(isVisible ? 1 : hiddenOpacity)
            .blur(radius: isVisible ? 0 : hiddenBlur)
            .animation(animation, value: isVisible)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, toastTrailingPadding)
            .onAppear {
                // Defer the visibility gate one run-loop tick so initial state is
                // always rendered hidden before we animate to visible.
                guard !didRenderOnce else { return }
                DispatchQueue.main.async {
                    didRenderOnce = true
                }
            }
            .onDisappear {
                didRenderOnce = false
            }
    }
}


fileprivate struct QuickDropToastViewButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToastButtonLabel(title: title, fillsWidth: false, showsBackground: true)
        }
        .buttonStyle(.plain)  // prevents blue macOS button look
    }
}


fileprivate struct QuickDropToastViewMenuButton<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            ToastButtonLabel(title: title, fillsWidth: false, showsBackground: true)
                .allowsHitTesting(false)

            Menu {
                content()
            } label: {
                ToastButtonLabel(title: title, fillsWidth: false, showsBackground: false)
            }
            .menuStyle(BorderlessButtonMenuStyle(showsMenuIndicator: false))
        }
        .fixedSize()
    }
}


fileprivate struct ToastButtonLabel: View {
    let title: String
    let fillsWidth: Bool
    let showsBackground: Bool

    var body: some View {
        Text(title.localized())
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.mainColor.opacity(showsBackground ? 0.75 : 0))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(Color.gray.opacity(showsBackground ? 0.1 : 0).cornerRadius(10))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
    }
}


fileprivate struct ActionColumn<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            content()
        }
        .padding(.vertical, 3)
        .padding(.trailing, 4)
        .frame(maxHeight: .infinity)
    }
}


fileprivate struct ActionButtonRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
    }
}


fileprivate struct ActionDividerLine: View {
    var body: some View {
        Rectangle()
            .foregroundColor(.mainColor.opacity(0.05))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}


struct AdaptiveToastBackgroundLayer: View {
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            } else {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: cornerRadius)
            }
        }
    }
}


// NSVisualEffectView wrapper for macOS 11 compatible blur/vibrancy
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var state: NSVisualEffectView.State = .active
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = state
        v.isEmphasized = true
        if cornerRadius > 0 {
            v.wantsLayer = true
            v.layer?.cornerRadius = cornerRadius
            v.layer?.masksToBounds = true
        }
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blendingMode
        v.state = state
        if cornerRadius > 0 {
            v.wantsLayer = true
            v.layer?.cornerRadius = cornerRadius
            v.layer?.masksToBounds = true
        } else {
            v.layer?.cornerRadius = 0
            v.layer?.masksToBounds = false
        }
    }
}


// Capsule-style linear progress (0...1)
struct CapsuleProgress: View {
    var value: Double
    var track = Color(NSColor.systemBlue).opacity(0.28)
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
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.25), value: value)
    }
}


// MARK: - Preview
struct QuickDropToastView_Previews: PreviewProvider {
    struct ConsentDemo: View {
        @State var model = ReceiveModel(controlPlusScreen: { _ in })

        var body: some View {
            QuickDropToastView(
                receiveModel: model,
                onCancel: { }
            )
            .frame(width: toastViewSize.width, height: toastViewSize.height)
            .clipped()
            .padding(100)
            .background(QuickDropToastView_Previews.previewWallpaper)
            .onAppear {
                model.consentState = .init(
                    transferID: "preview",
                    pinCodeMessage: "PIN: 1233",
                    message: "45 images from Pixel 6 Pro von Leon",
                    notificationSyncStage: nil,
                    allowsTrust: true,
                    acceptAction: { _ in },
                    declineAction: { }
                )
            }
        }
    }
    
    
    struct ConsentDemo2: View {
        @State var model = ReceiveModel(controlPlusScreen: { _ in })

        var body: some View {
            QuickDropToastView(
                receiveModel: model,
                onCancel: { }
            )
            .frame(width: toastViewSize.width, height: toastViewSize.height)
            .clipped()
            .padding(100)
            .background(QuickDropToastView_Previews.previewWallpaper)
            .onAppear {
                model.consentState = .init(
                    transferID: "preview",
                    pinCodeMessage: "PIN: 1233",
                    message: "45 images from Pixel 6 Pro",
                    notificationSyncStage: nil,
                    allowsTrust: false,
                    acceptAction: { _ in },
                    declineAction: { }
                )
            }
        }
    }
    

    struct ProgressDemo: View {
        @State var model = ReceiveModel(controlPlusScreen: { _ in })

        var body: some View {
            QuickDropToastView(
                receiveModel: model,
                onCancel: { }
            )
            .frame(width: toastViewSize.width, height: toastViewSize.height)
            .clipped()
            .padding(100)
            .background(QuickDropToastView_Previews.previewWallpaper)
            .onAppear {
                model.progress = 0.42
                model.toastActions = nil
            }
        }
    }
    

    struct CompletedDemo: View {
        @State var model = ReceiveModel(controlPlusScreen: { _ in })

        var body: some View {
            QuickDropToastView(
                receiveModel: model,
                onCancel: { }
            )
            .frame(width: toastViewSize.width, height: toastViewSize.height)
            .clipped()
            .padding(100)
            .background(previewWallpaper)
            .onAppear {
                model.progress = 1
                model.toastActions = .init(completionMessageKey: "Saved", autoHideDelay: 10, openFilesAction: {}, importPhotosAction: {}, closeToastAction: {}, autoHideAction: {})
            }
        }
    }
    

    private static let previewWallpaper = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0.92, green: 0.82, blue: 0.94),
            Color(red: 0.86, green: 0.76, blue: 0.90),
            Color(red: 0.78, green: 0.70, blue: 0.86)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    

    static var previews: some View {
        Group {
            ConsentDemo()
            ConsentDemo2()
            ProgressDemo()
            CompletedDemo()
        }
    }
}
