// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if TUIST
import struct ProjectDescription.PackageSettings
let packageSettings = PackageSettings(
    productTypes: [
        "UnrarKit": .framework
    ]
)
#endif

let package = Package(
    name: "UnrarKit",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "UnrarKit",
            targets: ["UnrarKit", "UnrarKitCategories"]),
    ],
    targets: [
        .target(
            name: "UnrarKit",
            path: ".",
            exclude: [
                "Example",
                "Resources",
                "Scripts",
                "Tests",
                "UnrarKit.xcodeproj",
                "UnrarKit.xcworkspace",
                "UnrarKit.podspec",
                "README.md",
                "LICENSE",
                "CHANGELOG.md",
                "beta-notes.md",
                "Classes/Categories"
            ],
            sources: [
                "Classes/URKArchive.mm",
                "Classes/URKFileInfo.m",
                "Libraries/unrar/archive.cpp",
                "Libraries/unrar/arcread.cpp",
                "Libraries/unrar/blake2s.cpp",
                "Libraries/unrar/cmddata.cpp",
                "Libraries/unrar/consio.cpp",
                "Libraries/unrar/crc.cpp",
                "Libraries/unrar/crypt.cpp",
                "Libraries/unrar/dll.cpp",
                "Libraries/unrar/encname.cpp",
                "Libraries/unrar/errhnd.cpp",
                "Libraries/unrar/extinfo.cpp",
                "Libraries/unrar/extract.cpp",
                "Libraries/unrar/filcreat.cpp",
                "Libraries/unrar/file.cpp",
                "Libraries/unrar/filefn.cpp",
                "Libraries/unrar/filestr.cpp",
                "Libraries/unrar/find.cpp",
                "Libraries/unrar/getbits.cpp",
                "Libraries/unrar/global.cpp",
                "Libraries/unrar/hash.cpp",
                "Libraries/unrar/headers.cpp",
                "Libraries/unrar/isnt.cpp",
                "Libraries/unrar/list.cpp",
                "Libraries/unrar/match.cpp",
                "Libraries/unrar/options.cpp",
                "Libraries/unrar/pathfn.cpp",
                "Libraries/unrar/qopen.cpp",
                "Libraries/unrar/rar.cpp",
                "Libraries/unrar/rarvm.cpp",
                "Libraries/unrar/rawread.cpp",
                "Libraries/unrar/rdwrfn.cpp",
                "Libraries/unrar/recvol.cpp",
                "Libraries/unrar/resource.cpp",
                "Libraries/unrar/rijndael.cpp",
                "Libraries/unrar/rs.cpp",
                "Libraries/unrar/rs16.cpp",
                "Libraries/unrar/scantree.cpp",
                "Libraries/unrar/secpassword.cpp",
                "Libraries/unrar/sha1.cpp",
                "Libraries/unrar/sha256.cpp",
                "Libraries/unrar/smallfn.cpp",
                "Libraries/unrar/strfn.cpp",
                "Libraries/unrar/strlist.cpp",
                "Libraries/unrar/system.cpp",
                "Libraries/unrar/threadpool.cpp",
                "Libraries/unrar/timefn.cpp",
                "Libraries/unrar/ui.cpp",
                "Libraries/unrar/unicode.cpp",
                "Libraries/unrar/unpack.cpp",
                "Libraries/unrar/volume.cpp"
            ],
            publicHeadersPath: "Classes/include",
            cxxSettings: [
                .headerSearchPath("Libraries/unrar"),
                .headerSearchPath("Classes"),
                .headerSearchPath("Classes/Categories"),
                .define("RARDLL"),
                .define("UNRAR"),
                .define("_UNIX"),
                .define("_FILE_OFFSET_BITS", to: "64"),
                .define("LARGEFILE_SOURCE"),
                .unsafeFlags(["-Wno-everything"])
            ],
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .target(
            name: "UnrarKitCategories",
            dependencies: ["UnrarKit"],
            path: "Classes/Categories",
            sources: [
                "NSString+UnrarKit.mm"
            ],
            cxxSettings: [
                .headerSearchPath("../../Libraries/unrar"),
                .headerSearchPath(".."),
                .define("RARDLL"),
                .define("UNRAR"),
                .define("_UNIX"),
                .define("_FILE_OFFSET_BITS", to: "64"),
                .define("LARGEFILE_SOURCE"),
                .unsafeFlags(["-Wno-everything"])
            ]
        )
    ],
    cxxLanguageStandard: .cxx11
)
