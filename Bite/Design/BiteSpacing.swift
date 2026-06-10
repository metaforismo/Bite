import SwiftUI

/// 4-pt rhythm spacing scale. Apply with `.padding(.bSpace(.md))` or
/// pass `.value` directly to `HStack(spacing:)`.
enum BiteSpace {
    case xxs, xs, sm, md, lg, xl, xxl

    var value: CGFloat {
        switch self {
        case .xxs: return 4
        case .xs:  return 8
        case .sm:  return 12
        case .md:  return 16
        case .lg:  return 20
        case .xl:  return 24
        case .xxl: return 32
        }
    }
}

extension View {
    func bSpace(_ space: BiteSpace, _ edges: Edge.Set = .all) -> some View {
        padding(edges, space.value)
    }
}
