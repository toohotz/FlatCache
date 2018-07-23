//
//  FlatCacheTests.swift
//  FreetimeTests
//
//  Created by Ryan Nystrom on 10/21/17.
//  Copyright © 2017 Ryan Nystrom. All rights reserved.
//

import XCTest

struct CacheModel: Cachable, Hashable {
    let id: String
    let value: String
    
    var hashValue: Int {
        return id.hashValue ^ value.hashValue
    }
}

class CacheModelListener: FlatCacheListener {
    var receivedItemQueue = [CacheModel]()
    var receivedListQueue = [[CacheModel]]()
    lazy var tempItems = [Any]()
    
    func flatCacheDidUpdate(cache: FlatCache, update: FlatCache.Update) {
        switch update {
        case .item(let item): receivedItemQueue.append(item as! CacheModel)
        case .list(let list): receivedListQueue.append(list as! [CacheModel])
        case .removeItem(let item):
            if let item = item as? CacheModel {
              receivedItemQueue = receivedItemQueue.lazy.filter {$0.id != item.id && $0.value != item.value}
            }
        case .removeItems(let items, let isFinished):
            tempItems.append(items)
            if isFinished {
                var flattenedList = [CacheModel]()
                for list in tempItems {
                    if let cacheList = list as? [CacheModel] {
                        flattenedList.append(contentsOf: cacheList)
                    }
                }
                let itemsToRemoveSet = Set(flattenedList)
                let itemsToRemove = Array(itemsToRemoveSet)
                for list in receivedListQueue {
                    let diffedList = Set(list).subtracting(itemsToRemove)
                    if list == receivedListQueue.first { receivedListQueue.removeAll() }
                    receivedListQueue.append(Array(diffedList))
                }
            }
        }
    }
}

struct OtherCacheModel: Cachable {
    let id: String
}

class FlatCacheTests: XCTestCase {
    
    func test_whenSettingSingleModel_thatResultExistsForType() {
        let cache = FlatCache()
        cache.set(value: CacheModel(id: "1", value: ""))
        XCTAssertNotNil(cache.get(id: "1") as CacheModel?)
    }

    func test_whenSettingSingleModel_withUupdatedModel_thatResultMostRecent() {
        let cache = FlatCache()
        cache.set(value: CacheModel(id: "1", value: "foo"))
        cache.set(value: CacheModel(id: "1", value: "bar"))
        XCTAssertEqual((cache.get(id: "1") as CacheModel?)?.value, "bar")
    }

    func test_whenSettingSingleModel_thatNoResultExsistForUnsetId() {
        let cache = FlatCache()
        cache.set(value: CacheModel(id: "1", value: ""))
        XCTAssertNil(cache.get(id: "2") as CacheModel?)
    }

    func test_whenSettingSingleModel_thatNoResultExistsForOtherType() {
        let cache = FlatCache()
        cache.set(value: CacheModel(id: "1", value: ""))
        XCTAssertNil(cache.get(id: "1") as OtherCacheModel?)
    }

    func test_whenSettingManyModels_thatResultsExistForType() {
        let cache = FlatCache()
        cache.set(values: [
            CacheModel(id: "1", value: ""),
            CacheModel(id: "2", value: ""),
            CacheModel(id: "3", value: ""),
            ])
        XCTAssertNotNil(cache.get(id: "1") as CacheModel?)
        XCTAssertNotNil(cache.get(id: "2") as CacheModel?)
        XCTAssertNotNil(cache.get(id: "3") as CacheModel?)
    }

    func test_whenSettingSingleModel_withListeners_whenMultipleUpdates_thatCorrectListenerReceivesUpdate() {
        let cache = FlatCache()
        let l1 = CacheModelListener()
        let l2 = CacheModelListener()
        let m1 = CacheModel(id: "1", value: "")
        let m2 = CacheModel(id: "2", value: "")
        cache.add(listener: l1, value: m1)
        cache.add(listener: l2, value: m2)
        cache.set(value: m1)
        cache.set(value: CacheModel(id: "1", value: "foo"))
        XCTAssertEqual(l1.receivedItemQueue.count, 2)
        XCTAssertEqual(l1.receivedListQueue.count, 0)
        XCTAssertEqual(l1.receivedItemQueue.last?.id, "1")
        XCTAssertEqual(l1.receivedItemQueue.last?.value, "foo")
        XCTAssertEqual(l2.receivedItemQueue.count, 0)
        XCTAssertEqual(l2.receivedListQueue.count, 0)
    }

    func test_whenSettingMultipleModels_withListenerOnAll_whenMultipleUpdates_thatListenerReceivesUpdate() {
        let cache = FlatCache()
        let l1 = CacheModelListener()
        let m1 = CacheModel(id: "1", value: "foo")
        let m2 = CacheModel(id: "2", value: "bar")
        cache.add(listener: l1, value: m1)
        cache.add(listener: l1, value: m2)
        cache.set(values: [m1, m2])
        XCTAssertEqual(l1.receivedItemQueue.count, 0)
        XCTAssertEqual(l1.receivedListQueue.count, 1)
        XCTAssertEqual(l1.receivedListQueue.last?.count, 2)
        XCTAssertEqual(l1.receivedListQueue.last?.first?.value, "foo")
        XCTAssertEqual(l1.receivedListQueue.last?.last?.value, "bar")
    }

    func test_whenSettingTwoModels_withListenerForEach_thatListenersReceiveItemUpdates() {
        let cache = FlatCache()
        let l1 = CacheModelListener()
        let l2 = CacheModelListener()
        let m1 = CacheModel(id: "1", value: "foo")
        let m2 = CacheModel(id: "2", value: "bar")
        cache.add(listener: l1, value: m1)
        cache.add(listener: l2, value: m2)
        cache.set(values: [m1, m2])
        XCTAssertEqual(l1.receivedItemQueue.count, 1)
        XCTAssertEqual(l1.receivedListQueue.count, 0)
        XCTAssertEqual(l1.receivedItemQueue.last?.value, "foo")
        XCTAssertEqual(l2.receivedItemQueue.count, 1)
        XCTAssertEqual(l2.receivedListQueue.count, 0)
        XCTAssertEqual(l2.receivedItemQueue.last?.value, "bar")
    }
    
    func test_removeResult_UsingRawKeyString() {
        let cache = FlatCache()
        let model = CacheModel(id: "hello", value: "world")
        cache.set(value: model)
        XCTAssertNotNil(cache.get(id: "hello") as CacheModel?)
        do {
            let val = try cache.remove(key: "hello") as CacheModel
            XCTAssertNotNil(val)
        } catch FlatCacheError.valueNotFound(let key) {
            XCTAssert(false, "No value found for key: - \(key)")
        } catch {
            XCTAssert(true, "\(error)")
        }
    }
    
    func test_RemoveResult_withListener() {
        let cache = FlatCache()
        let m1 = CacheModel(id: "foo", value: "bar")
        let m2 = CacheModel(id: "bar", value: "foo")
        let m3 = CacheModel(id: "hello", value: "world")
        let l1 = CacheModelListener()
        let l2 = CacheModelListener()
        cache.add(listener: l1, value: m1)
        cache.add(listener: l2, value: m1)
        cache.add(listener: l2, value: m2)
        cache.add(listener: l2, value: m3)
        cache.set(value: m1)
        cache.set(value: m2)
        cache.set(value: m3)
        XCTAssertEqual(l1.receivedItemQueue.count, 1)
        do {
            let cachedVal = try cache.remove(key: m1.id) as CacheModel
            let _ =  try cache.remove(key: m3.id) as CacheModel
            XCTAssertEqual(m1.value, cachedVal.value)
            XCTAssertEqual(l1.receivedItemQueue.count, 0)
            XCTAssertEqual(l2.receivedItemQueue.count, 1)
        } catch {
            XCTAssert(false, "\(error)")
        }
    }
    
    func test_RemoveResultList() {
        let cache = FlatCache()
        let m1 = CacheModel(id: "foo", value: "bar")
        let m2 = CacheModel(id: "bar", value: "foo")
        let m3 = CacheModel(id: "hello", value: "world")
        let m4 = CacheModel(id: "m4", value: "m4_value")
        let m5 = CacheModel(id: "m5", value: "m5_value")
        let m6 = CacheModel(id: "m6", value: "m6_value")
        let l1 = CacheModelListener()
        cache.add(listener: l1, value: m1)
        cache.add(listener: l1, value: m2)
        cache.add(listener: l1, value: m3)
        cache.add(listener: l1, value: m4)
        cache.add(listener: l1, value: m5)
        cache.add(listener: l1, value: m6)
        
        cache.set(values: [m1, m2, m3])
        cache.set(value: m4)
        cache.set(values: [m5, m6])
        
        XCTAssertEqual(1, l1.receivedItemQueue.count)
        
        do {
            let removedVals: [CacheModel] = try cache.unset(keys: ["foo", "bar", "m6"])
            XCTAssertEqual(3, removedVals.count)
        } catch FlatCacheError.valueNotFound(let key) {
            XCTAssert(false, "Invalid key found: \(key)")
        } catch {
            XCTAssert(false, "Error: \(error)")
        }
        // Should only have a single item and list left over
        XCTAssertEqual(1, l1.receivedListQueue.first?.count)
        XCTAssertEqual(1, l1.receivedListQueue.last?.count)
    }
}
