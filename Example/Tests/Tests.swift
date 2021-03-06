import UIKit
import XCTest
import CheapRulerIOS
import JavaScriptCore

class Tests: XCTestCase {
    
    var ruler: CheapRuler!
    var milesRuler: CheapRuler!
    var lines: [[[Double]]]?
    var points: [[Double]]?
    var expectations: [String: AnyObject]?
    
    override func setUp() {
        super.setUp()
        
        self.ruler = CheapRuler(lat: 32.8351, units: nil)
        self.milesRuler = CheapRuler(lat: 32.8351, units: CheapRuler.Factor.Miles)
        
        let linesPath = Bundle(for: type(of: self)).path(forResource: "lines", ofType: "json")
        let expectationsPath = Bundle(for: type(of: self)).path(forResource: "expectations", ofType: "json")
        do {
            var jsonData = try NSData(contentsOfFile: linesPath!) as Data
            let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [[[Double]]]
            self.lines = json
            self.points = Array(json.joined())
            
            jsonData = try NSData(contentsOfFile: expectationsPath!) as Data
            self.expectations = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: AnyObject]
        }
        catch {
            assert(false, "Json error")
        }
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testDistance() {
        let expected = self.expectations?["distance"] as! [Double]
        
        for i in 0 ..< self.points!.count - 1 {
            let actual = self.ruler.distance(a: points![i], b: points![i + 1])
            XCTAssertLessThan(abs(expected[i] - actual), 1e-12)
        }
    }
    
    func testDistanceInMiles() {
        let d = self.ruler.distance(a: [30.5, 32.8351], b: [30.51, 32.8451])
        let d2 = self.milesRuler.distance(a: [30.5, 32.8351], b: [30.51, 32.8451])
        XCTAssertLessThan(abs(d / d2 - 1.609344), 1e-12)
    }
    
    func testBearing() {
        let expected = self.expectations?["bearing"] as! [Double]
        
        for i in 0 ..< self.points!.count - 1 {
            let actual = self.ruler.bearing(a: points![i], b: points![i + 1])
            XCTAssertLessThan(abs(expected[i] - actual), 1e-12)
        }
    }
    
    func testDestination() {
        let expected = self.expectations?["destination"] as! [[Double]]
        
        for i in 0 ..< self.points!.count {
            let bearing = Double((i % 360) - 180)
            let actual = self.ruler.destination(p: self.points![i], dist: 1.0, bearing: bearing)
            XCTAssertLessThan(abs(expected[i][0] - actual[0]), 1e-12)
            XCTAssertLessThan(abs(expected[i][1] - actual[1]), 1e-12)
        }
    }
    
    func testLineDistance() {
        let expected = self.expectations?["lineDistance"] as! [Double]
        
        for i in 0 ..< self.lines!.count {
            let actual = self.ruler.lineDistance(points: self.lines![i])
            XCTAssertLessThan(abs(expected[i] - actual), 1e-12)
        }
    }
    
    func testArea() {
        let expected = self.expectations?["area"] as! [Double]
        
        let polygons = self.lines!.filter({ $0.count >= 3 })
        for i in 0 ..< polygons.count {
            let actual = self.ruler.area(polygon: [polygons[i]])
            XCTAssertLessThan(abs(expected[i] - actual), 1e-12)
        }
    }
    
    func testAlong() {
        let expected = self.expectations?["along"] as! [[Double]]
        
        for i in 0 ..< self.lines!.count {
            let distance = self.ruler.lineDistance(points: self.lines![i]) / 2
            let actual = self.ruler.along(line: self.lines![i], dist: distance)
            XCTAssertLessThan(abs(expected[i][0] - actual[0]), 1e-12)
            XCTAssertLessThan(abs(expected[i][1] - actual[1]), 1e-12)
        }
    }
    
    func testAlongWithNegativeDistance() {
        let line = self.lines![0]
        XCTAssertEqual(self.ruler.along(line: line, dist: -5), line[0])
    }
    
    func testAlongWithExcessDistance() {
        let line = self.lines![0]
        XCTAssertEqual(self.ruler.along(line: line, dist: 1000), line.last!)
    }
    
    func testPointOnLine() {
        let line = [[-77.031669, 38.878605], [-77.029609, 38.881946]];
        let p = self.ruler.pointOnLine(line, p: [-77.034076, 38.882017]).point;
        XCTAssertEqual(p, [-77.03052697027461, 38.880457194811896])
    }
    
    func testLineSlice() {
        let expected = self.expectations?["lineSlice"] as! [Double]
        var lines = self.lines!
        lines.remove(at: 46)
        
        for i in 0 ..< lines.count {
            let line = lines[i]
            let dist = self.ruler.lineDistance(points: line)
            let start = self.ruler.along(line: line, dist: dist * 0.3)
            let stop = self.ruler.along(line: line, dist: dist * 0.7)
            
            let actual = self.ruler.lineDistance(points: ruler.lineSlice(start: start, stop: stop, line: line))
            XCTAssertLessThan(abs(expected[i] - actual), 1e-12)
        }
    }
    
    func testLineSliceAlong() {
        let expected = self.expectations?["lineSliceAlong"] as! [Double]
        var lines = self.lines!
        lines.remove(at: 46)
        
        for i in 0 ..< lines.count {
            let line = lines[i]
            let dist = self.ruler.lineDistance(points: line)
            
            let actual = self.ruler.lineDistance(points: ruler.lineSliceAlong(start: dist * 0.3, stop: dist * 0.7, line: line))
            XCTAssertLessThan(abs(expected[i] - actual), 1e-12)
        }
    }
    
    func testLineSliceReverse() {
        let line = lines![0]
        let dist = self.ruler.lineDistance(points: line)
        let start = self.ruler.along(line: line, dist: dist * 0.7)
        let stop = self.ruler.along(line: line, dist: dist * 0.3)
        let actual = self.ruler.lineDistance(points: ruler.lineSlice(start: start, stop: stop, line: line))
        XCTAssertEqual(actual, 0.018676802802910702)
    }
    
    func testBufferPoint() {
        let expected = self.expectations?["bufferPoint"] as! [[Double]]
        
        for i in 0 ..< self.points!.count {
            let actual = self.milesRuler.bufferPoint(p: self.points![i], buffer: 0.1)
            XCTAssertLessThan(abs(expected[i][0] - actual[0]), 1e-12)
            XCTAssertLessThan(abs(expected[i][1] - actual[1]), 1e-12)
            XCTAssertLessThan(abs(expected[i][2] - actual[2]), 1e-12)
            XCTAssertLessThan(abs(expected[i][3] - actual[3]), 1e-12)
        }
    }
    
    func testBufferBBox() {
        let bbox = [30.0, 38.0, 40.0, 39.0];
        let bbox2 = self.ruler.bufferBBox(bbox: bbox, buffer: 1);
        XCTAssertEqual(bbox2, [29.989319515875376, 37.99098271225711, 40.01068048412462, 39.00901728774289])
    }
    
    func testInsideBBox() {
        let bbox = [30.0, 38.0, 40.0, 39.0];
        XCTAssertTrue(self.ruler.insideBBox(p: [35, 38.5], bbox: bbox))
        XCTAssertFalse(self.ruler.insideBBox(p: [45, 45], bbox: bbox))
    }
}
