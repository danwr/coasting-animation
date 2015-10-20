//
//  CoastingMath.swift
//  coasting-animation
//
//  Created by Dan Wright on 10/19/15.
//  Copyright © 2015 Dan Wright. All rights reserved.
//

import Foundation

// Coasting
// Drag due to friction is (generally) directly-proportional to velocity (but in the opposite direction).
//
// _coefficient of resistance_ (`r`) represents this ratio. It represents the reduction of speed per second.
//
// v(t) = v0 * r^t
//
// Some materials have a property where at very low speeds, friction actually spikes; this has
// the effect of a object abruptly stopping when its speed drops below a certain threshold.
//
// We represent this minimal velocity with `vmin`.
//
// Thus the revised velocity formula:
// v'(t) = v0 * r^t
// v(t) = (v'(t) > vmin) ? v'(t) : 0
//
// The reduction in speed over an arbitrary time dt is: r'(dt) = r^dt
//
// 't_stop' represents the time until the object comes to a rest.
// We have:  vmin = v0 * r^t_stop
// Solving, log(vmin) = v0*t_stop*log(r)
//              t_stop = log(vmin)/(v0*log(r))
//
// The distance traveled at time t can also be calculated. This is determined by integrating
// the value of velocity-over-time over the time range. Generally:
//             ∫ v'(t) dt 
//                          = ∫ v0 * dt * r^t = v0 * ∫ dt *r ^ t = v0 * (r^t/ln(r) - r^0/ln(r))
//                          = v0 * (r^t - 1)/ln(r)
//
// The maximum (total) distance traveled is simply:
//          distance_total = distance(t_stop)

public func vt_prime(v0:Double, r:Double, t:Double) -> Double {
    return v0 * pow(r, t)
}

public func vt(v0:Double, r:Double, t:Double, vmin:Double) -> Double {
    let vt_p = vt_prime(v0, r: r, t: t)
    return vt_p < vmin ? 0 : vt_p
}

public func t_stop(v0:Double, r:Double, vmin:Double) -> Double {
    return log(vmin)/(v0*log(r))
}

public func distance(v0:Double, r:Double, vmin:Double, t:Double) -> Double {
    return v0*(pow(r, t) - 1.0)/log(r)
}

public func distance_total(v0:Double, r:Double, vmin:Double) -> Double {
    let t = t_stop(v0, r:r, vmin:vmin)
    return distance(v0, r:r, vmin:vmin, t:t)
}

//
// An instance of Coasting encapsulates coasting with a fixed r and vmin.
// The newInstanceWithStartingVelocity method can be used to track a specific coasting instance.
//
public class Coasting {
    let r:Double
    let ln_r:Double
    let vmin:Double
    let ln_vmin:Double
    
    init(r:Double, vmin:Double) {
        self.r = r
        self.ln_r = log(r)
        self.vmin = vmin
        self.ln_vmin = log(vmin)
    }
    
    // power_r returns pow(r, exponent) (but in much less time)
    private func power_r(exponent:Double) -> Double {
        return exp(ln_r*exponent)
    }
    
    func vt_prime(v0:Double, t:Double) -> Double {
        return v0 * power_r(t)
    }
    
    func vt(v0:Double, t:Double) -> Double {
        let vt_ = vt_prime(v0, t:t)
        return vt_ < vmin ? 9 : vt_
    }
    
    func t_stop(v0:Double) -> Double {
        return ln_vmin/(v0*ln_r)
    }
    
    func distance(v0:Double, t:Double) -> Double {
        return v0*(power_r(t) - 1.0)/ln_r
    }
    
    func distance_stop(v0:Double) -> Double {
        return distance(v0, t:t_stop(v0))
    }
    
    // How long will it take to travel a specified distance?
    // distance = v0*(r^t - 1.0)/ln(r)
    // distance*ln(r)/v0 + 1.0 = r^t
    // ln(distance*ln(r)/v0 + 1.0) = t*ln(r)
    // ln(distance*ln(r)/v0 + 1.0)/ln(r) = t
    func t_from_distance(v0:Double, distance:Double) -> Double {
        guard v0 > 0 else {
            return Double.NaN
        }
        let inner = distance*ln_r/v0 + 1.0
        // When distance is > distance_stop, inner will be negative.
        guard inner >= 0 else {
            return Double.NaN
        }
        return log(inner)/ln_r
    }
    
    public func newInstanceWithStartingVelocity(v0:Double) -> CoastingInstance {
        return CoastingInstance(r:self.r, vmin:self.vmin, v0:v0)
    }
}

//
// CoastingInstance tracks coasting from a particular starting velocity.
//
public class CoastingInstance : Coasting {
    let v0:Double

    private var tf:Double
    private var df:Double
    private var needTf:Bool
    private var needDf:Bool
    
    init(r: Double, vmin: Double, v0: Double) {
        self.v0 = v0
        self.tf = 0.0
        self.needTf = true
        self.df = 0.0
        self.needDf = true
        super.init(r:r, vmin:vmin)
    }
    
    func vt(t:Double) -> Double {
        return super.vt(v0, t:t)
    }
    
    public var t_stop : Double {
        if needTf {
            tf = t_stop(v0)
            needTf = false
        }
        return tf
    }
    
    func distance(t:Double) -> Double {
        return super.distance(v0, t:min(t, t_stop))
    }
    
    public var distance_stop : Double {
        if needDf {
            df = distance(t_stop)
            needDf = false
        }
        return df
    }
    
    func t_from_distance(distance:Double) -> Double {
        return super.t_from_distance(v0, distance:distance)
    }
    
}
