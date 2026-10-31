// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RecipeKit",
    // RecipeCore のテストを Mac でも実行できるよう macOS も対象にする
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "RecipeCore", targets: ["RecipeCore"]),
        .library(name: "RecipeData", targets: ["RecipeData"]),
        .library(name: "RecipeUI", targets: ["RecipeUI"]),
    ],
    targets: [
        .target(name: "RecipeCore"),
        .target(name: "RecipeData", dependencies: ["RecipeCore"]),
        .target(name: "RecipeUI", dependencies: ["RecipeCore"]),
        .testTarget(name: "RecipeCoreTests", dependencies: ["RecipeCore"]),
        .testTarget(name: "RecipeDataTests", dependencies: ["RecipeData"]),
    ]
)
