//
//  CallbackList.swift
//  BabyMonitorRecorder
//
//  Created by Jackie Yang on 5/26/16.
//  Copyright © 2016 Jackie Yang. All rights reserved.
//

import UIKit

class CallbackList<Type> {
    var list: [(Type, Int)];
    var current = 0;
    let queue = dispatch_queue_create("me.jackieyang.callbacklist.serialqueue", DISPATCH_QUEUE_SERIAL)

    init() {
        list = [];
    }

    func addCallback(callback: Type) -> Int {
        var result = 0;
        dispatch_sync(queue) {
            self.list += [(callback, self.current)];
            result = self.current;
            self.current += 1;
        }
        return result;
    }

    func removeCallback(remove: Int) -> Void {
        dispatch_sync(queue) {
            self.list = self.list.filter({ (_, index) -> Bool in
                index != remove
            })
        }
    }

}
