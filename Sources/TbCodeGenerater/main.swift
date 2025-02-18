import Foundation
import Frontend

let frontendContentURL = Bundle.module.url(
    forResource: "FrontendOptions",
    withExtension: "td",
    subdirectory: "tds"
)
let frontendContent = try String(contentsOf: frontendContentURL!)

do {
    try print(FrontEndGenerater.generate(content: frontendContent))
} catch {
    print(error)
}
