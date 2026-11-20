//
//  PhotoDetailView.swift
//  EchoesOfTime
//
//  照片页：上方大图（黑底，图片靠上），下方浅色信息面板
//  右上角三个内容按钮：编辑 / 录制旁白 / 家人留言
//  面板顺序：照片名称 → 照片故事 → 旁白 → 家人留言（默认折叠）
//

import SwiftUI
import SwiftData

struct PhotoLightboxView: View {
    let photos: [Photo]
    let personID: UUID
    var isReader: Bool = false
    var person: Person? = nil

    @State private var index: Int
    @State private var player = AudioPlayer()
    @State private var showRecorder = false
    @State private var showMessages = false
    @State private var showEdit = false
    @State private var showShare = false
    @State private var showingPaywall = false
    @State private var storyExpanded = false
    @State private var narrationTotal: Double = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    init(photos: [Photo], personID: UUID, startIndex: Int, isReader: Bool = false, person: Person? = nil) {
        self.photos = photos
        self.personID = personID
        self.isReader = isReader
        self.person = person
        _index = State(initialValue: min(max(0, startIndex), max(0, photos.count - 1)))
    }

    private var photo: Photo? {
        photos.indices.contains(index) ? photos[index] : nil
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar

                    TabView(selection: $index) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { i, p in
                            page(p).tag(i)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: max(180, geo.size.height * 0.5))

                    if let p = photo {
                        contentPanel(p)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: index) { _, _ in
            player.stop()
            storyExpanded = false
            refreshNarrationDuration()
        }
        .onAppear { refreshNarrationDuration() }
        .onDisappear { player.stop() }
        .sheet(isPresented: $showMessages) {
            if let person, let p = photo {
                NavigationStack {
                    PhotoMessageBoard(person: person, photo: p)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let person, let p = photo {
                PhotoEditSheet(photo: p, person: person)
            }
        }
        .sheet(isPresented: $showShare) {
            if let person, let p = photo {
                PhotoShareSheet(photo: p, person: person, personID: personID)
            }
        }
        .sheet(isPresented: $showRecorder) {
            RecorderSheet(personID: personID, titleKey: "recorder.photo.title") { name, _ in
                guard let p = photo else { return }
                if let old = p.audioFileName {
                    MediaStore.deleteFile(fileName: old, personID: personID)
                }
                p.audioFileName = name
                try? context.save()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    // MARK: - 顶栏（右上角三个内容按钮）

    private var topBar: some View {
        HStack(spacing: 18) {
            Text("\(index + 1) / \(photos.count)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            if !isReader, person != nil {
                Button { showEdit = true } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel(Text("photo.edit.action"))

                Button {
                    if photo?.audioFileName != nil
                        || PurchaseManager.shared.canAddVoice(currentCount: person?.voiceNotes.count ?? 0) {
                        showRecorder = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Image(systemName: (photo?.audioFileName == nil) ? "mic" : "mic.fill")
                }
                .accessibilityLabel(Text("photo.record"))

                Button { showMessages = true } label: {
                    Image(systemName: "bubble.left.and.bubble.right")
                }
                .accessibilityLabel(Text("photo.messages"))

                Button {
                    if PurchaseManager.shared.canShare {
                        showShare = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("share.title"))
            }

            Button {
                player.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
            }
            .accessibilityLabel(Text("common.close"))
        }
        .font(.system(size: 19, weight: .medium))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    // MARK: - 图片页

    private func page(_ p: Photo) -> some View {
        Group {
            if let img = MediaStore.loadImage(fileName: p.imageFileName, personID: personID) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("photo.missing")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - 下方信息面板

    private func contentPanel(_ p: Photo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !p.caption.isEmpty {
                    Text(ArchiveText.inline(p.caption))
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !p.story.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("photo.story.title")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(ArchiveText.clean(p.story))
                            .font(.system(size: 15))
                            .lineSpacing(5)
                            .lineLimit(storyExpanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)

                        if p.story.count > 50 {
                            Button(storyExpanded ? "person.story.collapse" : "person.story.expand") {
                                withAnimation(.easeInOut(duration: 0.2)) { storyExpanded.toggle() }
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.brown)
                            .buttonStyle(.borderless)
                        }
                    }
                }

                narrationRow(p)

                if let person {
                    MessageSection(person: person, photo: p, isReader: isReader, showsInput: false)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.top, 6)
    }

    @ViewBuilder
    private func narrationRow(_ p: Photo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("photo.narration.title")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if !isReader {
                    Button {
                        showRecorder = true
                    } label: {
                        Label(p.audioFileName == nil ? "photo.record" : "photo.rerecord",
                              systemImage: "mic.circle")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.brown)
                }
            }

            if p.audioFileName != nil {
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: player.progress)
                            .tint(.brown)
                        HStack(spacing: 10) {
                            Button {
                                toggle(p)
                            } label: {
                                Label(
                                    player.isPlayingNow ? "photo.narration.pause" : "photo.narration.play",
                                    systemImage: player.isPlayingNow ? "pause.fill" : "play.fill"
                                )
                                .font(.system(size: 14, weight: .medium))
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.brown)

                            if narrationTotal > 0 {
                                Text(timerText)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            } else {
                Text("voice.empty")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var timerText: String {
        if player.isPlayingNow {
            return "\(AudioPlayer.timeText(player.currentTime)) / \(AudioPlayer.timeText(narrationTotal))"
        }
        return AudioPlayer.timeText(narrationTotal)
    }

    private func refreshNarrationDuration() {
        guard let p = photo, let name = p.audioFileName else {
            narrationTotal = 0
            return
        }
        narrationTotal = AudioPlayer.duration(of: MediaStore.url(fileName: name, personID: personID))
    }

    private func toggle(_ p: Photo) {
        guard let name = p.audioFileName else { return }
        let url = MediaStore.url(fileName: name, personID: personID)
        player.toggle(url: url)
    }
}

// MARK: - 照片留言板（独立弹出：留言列表在上，输入栏固定在键盘上方，顶部带关闭）

struct PhotoMessageBoard: View {
    let person: Person
    let photo: Photo

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var draft = ""
    @State private var expanded = false
    @State private var showingPaywall = false
    @FocusState private var editing: Bool

    private var messages: [Message] {
        person.messages
            .filter { !$0.isDeleted && $0.photo?.id == photo.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var visibleMessages: [Message] {
        expanded ? messages : Array(messages.suffix(2))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        Text("messages.empty")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    } else {
                        ForEach(visibleMessages) { msg in
                            messageRow(msg)
                        }

                        if messages.count > 2 {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(expanded ? "person.story.collapse" : "person.story.expand")
                                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.brown)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)

            inputBar
        }
        .navigationTitle("photo.messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.close") { dismiss() }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("messages.placeholder", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .focused($editing)

            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.brown)
            }
            .buttonStyle(.borderless)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func messageRow(_ msg: Message) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(msg.userName.isEmpty ? "Family" : msg.userName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.brown)
                Spacer()
                Text(msg.createdAt, style: .date)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(ArchiveText.inline(msg.content))
                .font(.system(size: 15))
                .lineSpacing(4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brown.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let total = person.messages.filter { !$0.isDeleted }.count
        guard PurchaseManager.shared.canAddMessage(currentCount: total) else {
            showingPaywall = true
            return
        }
        let author = UserDefaults.standard.string(forKey: "familyName") ?? "Family"
        let msg = Message(userName: author.isEmpty ? "Family" : author, content: text, role: "family")
        msg.person = person
        msg.photo = photo
        context.insert(msg)
        try? context.save()
        draft = ""
        editing = false
    }
}
