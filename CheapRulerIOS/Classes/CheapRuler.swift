//
//  CheapRuler.swift
//  CheapRuleriOS
//
//  Created by Roman Temchenko on 5/19/16.
//
//

import Foundation
import CoreLocation


public class CheapRuler {
    public enum Factor: Double {
        case Kilometers = 1
        case Miles = 0.62137119223733395
        case Nauticalmiles = 0.5399568034557235
        case Meters = 1000
        case Yards = 1093.6132983377079
        case Feet = 3280.8398950131232
        case Inches = 39370.078740157485
    }
    
    var cos1: Double
    var cos2: Double
    var cos3: Double
    var cos4: Double
    var cos5: Double
    
    var kx: Double
    var ky: Double
    
    public init(lat: CLLocationDegrees, units: Factor?) {
        let m = (units != nil) ? units!.rawValue : 1
        
        self.cos1 = cos(lat * M_PI / 180)
        self.cos2 = 2 * self.cos1 * self.cos1 - 1
        self.cos3 = 2 * self.cos1 * self.cos2 - self.cos1
        self.cos4 = 2 * self.cos1 * self.cos3 - self.cos2
        self.cos5 = 2 * self.cos1 * self.cos4 - self.cos3
        
        // multipliers for converting longitude and latitude degrees into distance (http://1.usa.gov/1Wb1bv7)
        self.kx = m * (111.41513 * cos1 - 0.09455 * cos3 + 0.00012 * cos5)
        self.ky = m * (111.13209 - 0.56605 * cos2 + 0.0012 * cos4)
    }
    
    public convenience init(fromTile y: Double, z: Double, units: Factor?) {
        let n = M_PI * (1 - 2 * (y + 0.5) / pow(2, z))
        let lat = atan(0.5 * (exp(n) - exp(-n))) * 180 / M_PI
        
        self.init(lat: lat, units: units)
    }
    
    public func distance (a: [CLLocationDegrees], b: [CLLocationDegrees]) -> CLLocationDistance {
        let dx = (a[0] - b[0]) * self.kx
        let dy = (a[1] - b[1]) * self.ky
        return sqrt(dx * dx + dy * dy)
    }
    
    public func bearing (a: [CLLocationDegrees], b: [CLLocationDegrees]) -> CLLocationDirection {
        let dx = (b[0] - a[0]) * self.kx
        let dy = (b[1] - a[1]) * self.ky
        if (dx == 0 && dy == 0) { return 0 }
        var bearing = atan2(-dy, dx) * 180 / M_PI + 90
        if (bearing > 180) { bearing -= 360 }
        return bearing
    }
    
    public func destination (p: [CLLocationDegrees], dist: CLLocationDistance, bearing: CLLocationDirection) -> [CLLocationDegrees] {
        let a = (90 - bearing) * M_PI / 180
        return [
            p[0] + cos(a) * dist / self.kx,
            p[1] + sin(a) * dist / self.ky
        ]
    }
    
    public func lineDistance (points: [[CLLocationDegrees]]) -> CLLocationDistance {
        var total = 0.0
        
        for i in 0.stride(to: points.count - 1, by: 1)  {
            total += self.distance(points[i], b: points[i + 1])
        }
        return total
    }
    
    public func area (polygon: [[[CLLocationDegrees]]]) -> Double {
        var sum = 0.0
        
        for i in 0.stride(to: polygon.count, by: 1) {
            var ring = polygon[i]
            
            var k = ring.count - 1
            for j in 0.stride(to: ring.count, by: 1) {
                let pj = ring[j]
                let pk = ring[k]
                sum += (pj[0] - pk[0]) * (pj[1] + pk[1]) * (i != 0 ? -1 : 1)
                k = j
            }
        }
        
        return (abs(sum) / 2) * self.kx * self.ky
    }
    
    public func along (line: [[CLLocationDegrees]], dist: CLLocationDistance) -> [CLLocationDegrees] {
        var sum = 0.0
        
        if (dist <= 0) { return line[0] }
        
        for i in 0.stride(to: line.count - 1, by: 1) {
            let p0 = line[i]
            let p1 = line[i + 1]
            let d = self.distance(p0, b: p1)
            sum += d
            if (sum > dist) { return interpolate(p0, b: p1, t: (dist - (sum - d)) / d) }
        }
        
        return line[line.count - 1]
    }
    
    public func pointOnLine (line: [[CLLocationDegrees]], p: [CLLocationDegrees]) -> (point: [CLLocationDegrees], index: Int, t: Double) {
        var minDist = Double.infinity
        var minX = 0.0
        var minY = 0.0
        var minT = 0.0
        var minI = 0
        
        for i in 0.stride(to: line.count - 1, by: 1) {
            var t = 0.0
            var x = line[i][0]
            var y = line[i][1]
            var dx = (line[i + 1][0] - x) * self.kx
            var dy = (line[i + 1][1] - y) * self.ky
            
            if (dx != 0 || dy != 0) {
                
                t = ((p[0] - x) * self.kx * dx + (p[1] - y) * self.ky * dy) / (dx * dx + dy * dy)
                
                if (t > 1) {
                    x = line[i + 1][0]
                    y = line[i + 1][1]
                    
                } else if (t > 0) {
                    x += (dx / self.kx) * t
                    y += (dy / self.ky) * t
                }
            }
            
            dx = (p[0] - x) * self.kx
            dy = (p[1] - y) * self.ky
            
            let sqDist = dx * dx + dy * dy
            if (sqDist < minDist) {
                minDist = sqDist
                minX = x
                minY = y
                minI = i
                minT = t
            }
        }
        
        return (
            [minX, minY],
            minI,
            minT
        )
    }
    
    public func lineSlice (start: [CLLocationDegrees], stop: [CLLocationDegrees], line: [[CLLocationDegrees]]) -> [[CLLocationDegrees]] {
        var p1 = self.pointOnLine(line, p: start)
        var p2 = self.pointOnLine(line, p: stop)
        
        if (p1.index > p2.index || (p1.index == p2.index && p1.t > p2.t)) {
            let tmp = p1
            p1 = p2
            p2 = tmp
        }
        
        var slice = [p1.point]
        
        let l = p1.index + 1
        let r = p2.index
        
        if (!equals(line[l], b: slice[0]) && l <= r) {
            slice.append(line[l])
        }
        
        for i in (l + 1).stride(through: r, by: 1) {
            slice.append(line[i])
        }
        
        if (!equals(line[r], b: p2.point)) {
            slice.append(p2.point)
        }
        
        return slice
    }
    
    public func lineSliceAlong (start: CLLocationDistance, stop: CLLocationDistance, line: [[CLLocationDegrees]]) -> [[CLLocationDegrees]] {
        var sum = 0.0
        var slice:[[CLLocationDegrees]] = []
        
        for i in 0.stride(to: line.count - 1, by: 1) {
            let p0 = line[i]
            let p1 = line[i + 1]
            let d = self.distance(p0, b: p1)
            
            sum += d
            
            if (sum > start && slice.count == 0) {
                slice.append(interpolate(p0, b: p1, t: (start - (sum - d)) / d))
            }
            
            if (sum >= stop) {
                slice.append(interpolate(p0, b: p1, t: (stop - (sum - d)) / d))
                return slice
            }
            
            if (sum > start) { slice.append(p1) }
        }
        
        return slice
    }
    
    public func bufferPoint (p: [CLLocationDegrees], buffer: CLLocationDistance) -> [CLLocationDegrees] {
        let v = buffer / self.ky
        let h = buffer / self.kx
        return [
            p[0] - h,
            p[1] - v,
            p[0] + h,
            p[1] + v
        ]
    }
    
    public func bufferBBox (bbox: [CLLocationDegrees], buffer: CLLocationDistance) -> [CLLocationDegrees] {
        let v = buffer / self.ky
        let h = buffer / self.kx
        return [
            bbox[0] - h,
            bbox[1] - v,
            bbox[2] + h,
            bbox[3] + v
        ]
    }
    
    public func insideBBox (p: [CLLocationDegrees], bbox: [CLLocationDegrees]) -> Bool {
        return p[0] >= bbox[0] &&
            p[0] <= bbox[2] &&
            p[1] >= bbox[1] &&
            p[1] <= bbox[3]
    }
}

func equals(a: [CLLocationDegrees], b: [CLLocationDegrees]) -> Bool {
    return a[0] == b[0] && a[1] == b[1]
}

func interpolate(a: [CLLocationDegrees], b: [CLLocationDegrees], t: Double) -> [CLLocationDegrees] {
    let dx = b[0] - a[0]
    let dy = b[1] - a[1]
    return [
        a[0] + dx * t,
        a[1] + dy * t
    ]
}
