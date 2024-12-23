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
    
    var vm = FileListViewModel()
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    ForEach(vm.files, id: \.self) { file in
                        HStack {
                            Text(file)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedFile == file ? Color.blue : Color.clear, lineWidth: 2)
                        }
                        .onTapGesture {
                            GZLogFunc()
                            
                            Task {
                                GZLogFunc(Thread.isMainThread)
                                GZLogFunc()
                                model = PlyParser().loadLarge(from: file)
                                await MainActor.run {
                                    GZLogFunc(Thread.isMainThread)
                                    GZLogFunc()
                                    selectedFile = file
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .listRowSpacing(1)
            }
            .onAppear {
                vm.loadFiles()
            }
            .navigationDestination(item: $selectedFile) { fileName in
                MetalView(model: model!)
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
