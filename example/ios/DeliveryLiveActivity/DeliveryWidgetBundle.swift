import SwiftUI
import WidgetKit

@main
struct DeliveryWidgetBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            DeliveryLiveActivity()
            MinimalLiveActivity()
        }
    }
}
