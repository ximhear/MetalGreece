//
//  FileListView.swift
//  PlyViewer
//
//  Created by gzonelee on 12/24/24.
//

import SwiftUI

struct FileListView: View {
    
    @State var selectedFile: String?
    @State var model: Model?
    @State var isLoading: Bool = false
    
    var vm = FileListViewModel()
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(vm.files, id: \.self) { file in
                        HStack {
                            Text(file)
                            Spacer()
                        }
                        .padding(8)
                        .contentShape(Rectangle())
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedFile == file ? Color.blue : Color.clear, lineWidth: 2)
                        }
                        .onTapGesture {
                            GZLogFunc()

                            selectedFile = file
                            isLoading = true
                            Task {
                                model = await PlyParser().loadLarge(from: file)
                                await MainActor.run {
                                    isLoading = false
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSpacing(1)
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.5)
                        
                        ZStack {
                            ProgressView()
                                .scaleEffect(1.5, anchor: .center)
                                .tint(.white)
                        }
                        .padding(40)
                        .background(Color.init(uiColor: .init(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0)))
                        .cornerRadius(8)
                    }
                }
            }
            .onAppear {
                vm.loadFiles()
            }
            .onChange(of: model) { oldValue, newValue in
                GZLogFunc(newValue)
                if newValue == nil {
                    selectedFile = nil
                }
                
            }
            .navigationDestination(item: $model) { value in
                MetalView(model: value)
                    .edgesIgnoringSafeArea(.all)
                
            }
        }
    }
}

@Observable class FileListViewModel {
    var files: [String] = []
    var selectedFile: String = ""
    
    func loadFiles() {
        if let resourcePath = Bundle.main.resourcePath {
            let fileManager = FileManager.default
            let targetDirectory = resourcePath // + "/Resource/ply" // Resource 폴더 안에 있는 서브폴더
            GZLogFunc(targetDirectory)

            do {
                let items = try fileManager.contentsOfDirectory(atPath: targetDirectory)
                files = items.filter { $0.hasSuffix(".ply") }.map { $0.replacingOccurrences(of: ".ply", with: "") }.sorted()
                for item in files {
                    print("Found file: \(item)")
                }
            } catch {
                print("Error reading contents: \(error)")
            }
        }

    }
}

#Preview {
    FileListView()
}
