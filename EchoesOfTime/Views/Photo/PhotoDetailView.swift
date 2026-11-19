//
//  PhotoDetailView.swift
//  EchoesOfTime
//
//  照片灯箱：全屏大图 + 左右翻页 + 标题/故事 + 旁白播放
//

import SwiftUI

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
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { i, p in
                    page(p).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                if let photo { bottomBar(photo) }
            }
        }
        .onChange(of: index) { _, _ in player.stop() }
        .onDisappear { player.stop() }
        .sheet(isPresented: $showMessages) {
            if let person, let p = photo {
                NavigationStack {
                    ScrollView {
                        MessageSection(person: person, photo: p)
                            .padding(20)
                    }
                    .navigationTitle("photo.messages")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let person, let p = photo {
                PhotoEditSheet(photo: p, person: person)
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
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack {
            Text("\(index + 1) / \(photos.count)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
            Button {
                player.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    // MARK: - 图片页

    private func page(_ p: Photo) -> some View {
        Group {
            if let img = MediaStore.loadImage(fileName: p.imageFileName, personID: personID) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                    Text("photo.missing")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - 底部信息与播放

    private func bottomBar(_ p: Photo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !p.caption.isEmpty {
                Text(ArchiveText.inline(p.caption))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            if !p.story.isEmpty {
                Text(ArchiveText.inline(p.story))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(5)
            }

            if let person {
                let count = person.messages.filter { $0.photo?.id == p.id && !$0.isDeleted }.count
                Button {
                    showMessages = true
                } label: {
                    Label("photo.messages \(count)", systemImage: "bubble.left.and.bubble.right")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.95))
            }

            if !isReader, person != nil {
                Button {
                    showEdit = true
                } label: {
                    Label("photo.edit.action", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.95))
            }

            if !isReader {
                Button {
                    showRecorder = true
                } label: {
                    Label(p.audioFileName == nil ? "photo.record" : "photo.rerecord",
                          systemImage: "mic.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.95))
            }

            if p.audioFileName != nil {
                TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: player.progress)
                            .tint(.white)
                        Button {
                            toggle(p)
                        } label: {
                            Label(
                                player.isPlayingNow ? "photo.narration.pause" : "photo.narration.play",
                                systemImage: player.isPlayingNow ? "pause.circle.fill" : "play.circle.fill"
                            )
                            .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private func toggle(_ p: Photo) {
        guard let name = p.audioFileName else { return }
        let url = MediaStore.url(fileName: name, personID: personID)
        player.toggle(url: url)
    }
}
