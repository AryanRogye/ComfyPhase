//
//  NSScreen+persistantUUIDString.swift
//  ComfyTile
//
//  Created by Aryan Rogye on 9/21/26.
//

import AppKit

extension NSScreen {
    nonisolated var persistentUUIDString: String? {
        guard let displayID = self.displayID else { return nil }

        guard let cfuuidRef = CGDisplayCreateUUIDFromDisplayID(displayID) else { return nil }

        let cfuuid = cfuuidRef.takeRetainedValue()
        return CFUUIDCreateString(kCFAllocatorDefault, cfuuid) as String?
    }
}
