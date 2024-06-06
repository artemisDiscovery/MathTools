

import Foundation 
import Dispatch

let computeQueue = DispatchQueue( label:"compute", attributes: .concurrent )
let blocksQueue = DispatchQueue( label:"blocks" )


public struct Vector: Equatable {
    var n:Int
    public var coords:[Double]


    public init(_ coords:[Double]) {
        n = coords.count 
        self.coords = coords 
    }

    public func dist(_ other:Vector) -> Double {
        return sqrt( (0..<n) .map {pow(coords[$0] - other.coords[$0], 2)} .reduce(0.0) {$0 + $1} )
    }

    public func sub(_ other:Vector) -> Vector {
        return Vector( (0..<n) .map { coords[$0] - other.coords[$0]} )
    }

    public func add(_ other:Vector) -> Vector {
        return Vector( (0..<n) .map { coords[$0] + other.coords[$0]} )
    }

    public func scale(_ by:Double) -> Vector {
        return Vector( (0..<n) .map { by * coords[$0]} )
    }

    public func length() -> Double {
        return sqrt((0..<n) .map { coords[$0]*coords[$0] } .reduce(0.0) { $0 + $1 } )
    }

    public func unit() -> Vector? {
        let len = self.length()
        if len == 0.0 {
            return nil
        }
        else {
            return Vector(self.coords).scale(1.0/len)
        }   
        
    }

    public func cross( _ with:Vector) -> Vector {
        return Vector(  [coords[1]*with.coords[2] - with.coords[1]*coords[2],
                         coords[2]*with.coords[0] - with.coords[2]*coords[0],
                         coords[0]*with.coords[1] - with.coords[0]*coords[1]] )
    }

    public func dot( _ with:Vector) -> Double {
        return (0..<n) .map { coords[$0]*with.coords[$0] } .reduce(0.0) {$0 + $1}
    }

    public static func ==(lhs: Vector, rhs: Vector) -> Bool {
        for (x,y) in zip(lhs.coords,rhs.coords) {
            if x != y {
                return false
            }
        }
        return true
}

}

extension Range {
    func contains(otherRange: Range) -> Bool {
        lowerBound <= otherRange.lowerBound && upperBound >= otherRange.upperBound
    }
}

// extend arithmetic operators for vectors 


public func + (left:Vector, right:Vector) -> Vector {
    return left.add(right)
}

public func - (left:Vector, right:Vector) -> Vector {
    return left.sub(right)
}

public func * (left:Double, right:Vector) -> Vector {
    return right.scale(left)
}

public func * (left:Vector, right:Double) -> Vector {
    return left.scale(right)
}

public enum MatrixError: Error {
    case shapeError
    case sizeError
    case invalidIndex
    case sliceError
    case domainError
    case typeError
    
}


public class Matrix<T:Numeric> {

    var shape:[Int]

    var strides:[Int]

    var count:Int

    public var storage:Array<T> 

    public init( _ inputshape:[Int], content:[T]? = nil  )  {
        shape = inputshape 
        count = 1

        for d in shape {
            count *= d
        }

        strides = [Int]() 

        for sidx in 0..<(shape.count - 1) {
            var str = 1
            for sjdx in (sidx+1)..<shape.count {
                str *= shape[sjdx]
            }
            strides.append(str)
        }

        // always have stride 1 for last dimension

        strides.append(1)

        var rep:Any?

        if T.self == Double.self {
            rep = 0.0
        }
        else if T.self == Int.self {
            rep = 0
        }
        else if T.self == Bool.self  {
            rep = false
        }
        

        if content == nil {
            storage = Array(repeating:(rep as! T), count:count)
        }
        else {
            storage = content!
        }
        
        

    }

    // with shape si,sj,sk,sl stride_i = (sj*sk*sl), stride_j = sk*sl, stride_k = sl 
    // so index of element [i,j,k] = i*(sj*sk) + j*sk + k

    public func indicesFromIndex( _ index:Int ) throws -> [Int] {
        
        if index < 0 || index >= storage.count {
            throw MatrixError.invalidIndex
        }

        var indices = [Int]() 

        var remainder = index 

        for stride in strides {
            let idx = remainder / stride 
            indices.append(idx)
            remainder -= idx * stride 
        }

        return indices 
    }

    func advance (_ indice: inout [Int] ) {
        for pos in (0...(shape.count-1)).reversed() {
            indice[pos] += 1
            if indice[pos] == shape[pos] {
                indice[pos] = 0 
                continue
            }
            return
        }
    }

    public func indicesInOrder() -> [[Int]] {
        var indices = [[Int]]() 

        var currentIndice = Array(repeating:0, count:shape.count)

        for _ in 0..<count {
            indices.append(currentIndice)
            advance( &currentIndice )
        }

        return indices 
    }

    public func indexFromIndices( _ indices:[Int] ) throws -> Int {
        
        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0 

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }

            index += strides[sidx] * idx
        }

        return index 
    }

    // for a range in each dimension, return index range and buffer


    public func _slice_ranges( _ ranges:[Range<Int>] ) throws -> [T] {

        if ranges.count != shape.count {
            throw MatrixError.shapeError
        }

        for sidx in 0..<shape.count {
            if !(0..<shape[sidx]).contains(otherRange:ranges[sidx]) {
                throw MatrixError.invalidIndex
            }
        }
        var indices = ranges[0].map { $0 * strides[0] }

        for sidx in 1..<strides.count {
            // 
            var indices2 = [Int]()

            for idx in indices {
                for idx2 in ranges[sidx] {
                    indices2.append(idx + strides[sidx]*idx2)
                }
                indices = indices2
            } 

        }

        // coallesce into ranges

        // Start with spans, which are inclusive intervals

        var slicespans = [[Int]]() 

        var length = 0 

        var currentSpan = [indices[0],indices[0]] 

        for idx in indices[1..<indices.count] {
            
            if currentSpan[1] == idx - 1 {
                currentSpan[1] = idx
            }
            else {
                slicespans.append(currentSpan)
                length += currentSpan[1] - currentSpan[0] + 1
                currentSpan = [idx,idx]
            }
           
        }

        slicespans.append(currentSpan)
        length += currentSpan[1] - currentSpan[0] + 1

        let sliceranges = slicespans.map { $0[0]..<($0[1]+1) }

        var rep:Any?

        if T.self == Double.self {
            rep = 0.0
        }
        else if T.self == Int.self {
            rep = 0
        }
        else {
            rep = false
        }

        var buffer = Array(repeating:(rep as! T), count:length)

        var accum = 0 

        for range in sliceranges {
            _ = (range.enumerated()).map { buffer[accum + $0] = storage[$1] }
            accum += (range.upperBound - range.lowerBound)
        }

        return buffer

    }

    public func getSliceRanges( _ ranges:[Range<Int>] ) throws -> [Range<Int>] {

        if ranges.count != shape.count {
            throw MatrixError.shapeError
        }

        for sidx in 0..<shape.count {
            if !(0..<shape[sidx]).contains(otherRange:ranges[sidx]) {
                throw MatrixError.invalidIndex
            }
        }
        var indices = ranges[0].map { $0 * strides[0] }

        for sidx in 1..<strides.count {
            // 
            var indices2 = [Int]()

            for idx in indices {
                for idx2 in ranges[sidx] {
                    indices2.append(idx + strides[sidx]*idx2)
                }
                indices = indices2
            } 

        }

        // coallesce into ranges

        // Start with spans, which are inclusive intervals

        var slicespans = [[Int]]() 

        var length = 0 

        var currentSpan = [indices[0],indices[0]] 

        for idx in indices[1..<indices.count] {
            
            if currentSpan[1] == idx - 1 {
                currentSpan[1] = idx
            }
            else {
                slicespans.append(currentSpan)
                length += currentSpan[1] - currentSpan[0] + 1
                currentSpan = [idx,idx]
            }
           
        }

        slicespans.append(currentSpan)
        length += currentSpan[1] - currentSpan[0] + 1

        let sliceranges = slicespans.map { $0[0]..<($0[1]+1) }

        return sliceranges

    }

    public func slice( _ ranges:[Range<Int>] ) throws -> Matrix {
        var sliceshape = [Int]() 

        for range in ranges {
            sliceshape.append(range.upperBound - range.lowerBound )
        }

        //print("slice shape = \(sliceshape)")

        let theslice = Matrix<T>(sliceshape)

        var buffer:[T]?

        do {
            buffer = try _slice_ranges( ranges )
        }
        catch {
            throw MatrixError.sliceError
        }
        

        //print("buffer count = \(buffer.count)")
        //print("buffer : \(buffer)")

        // should work to just join values in order 

        //print("slice size = \(theslice.count)")
        //print("slice storage = \(theslice.storage)")

        _ = (0..<buffer!.count ).map { theslice.storage[$0] = buffer![$0] }

        return theslice

    }


    public func zeros() {
        var rep:Any?

        if T.self == Double.self {
            rep = 0.0
        }
        else if T.self == Int.self {
            rep = 0
        }
        else {
            rep = false
        }

        _ = (0..<count).map {  storage[$0] = (rep as! T) }
    }

    public func ones() {
        var rep:Any?

        if T.self == Double.self {
            rep = 1.0
        }
        else if T.self == Int.self {
            rep = 1
        }
        else {
            rep = true
        }
        _ = (0..<count).map { storage[$0] = (rep as! T) }
    }

    public func random(_ lower:Double = 0.0, _ upper:Double = 1.0 ) throws {
        if T.self == Double.self {
            _ = (0..<count).map { storage[$0] = ((upper - lower)*drand48() + lower) as! T }
        }
        else if T.self == Int.self {
            _ = (0..<count).map { storage[$0] = Int((upper - lower)*drand48() + lower) as! T }
        }
        else {
            throw MatrixError.typeError
        }
        
    }

    public func setValue(_ indices:[Int], _ value:T ) throws {
        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }

            index += idx * strides[sidx]
            if index < 0 || index >= storage.count {
                throw MatrixError.sizeError
            }
        }

        storage[index] = value 
        
    }

    public func getValue(_ indices:[Int] ) throws -> T {

        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }
            
            index += idx * strides[sidx]

            if index < 0 || index >= storage.count {
                throw MatrixError.sizeError
            }
        }

        return storage[index]
        
    }
    public func add( _ const:T) throws -> Matrix<T> {
        
        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let sum = storage .map { $0 + const }

        return Matrix<T>(shape, content:sum )

    }

    public func add( _ other:Matrix<T>) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let sum = (0..<storage.count) .map { storage[$0] + other.storage[$0] }
        //let sum = zip( storage, other.storage ) .map { $0 + $1 }

        return Matrix<T>(shape, content:sum )

    }

    public func addTranspose(_ other:Matrix<T>) throws -> Matrix<T> {
        // require same 1D shapes

        if shape.count != 1 || other.shape.count != 1 {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        var outstorage = [T]()

        for x in storage {
            let row = (0..<other.shape[0]) .map { x + other.storage[$0] }
            outstorage += row 
        }

        return Matrix<T>([shape[0],other.shape[0]], content:outstorage )
    }

    public func subtractTranspose(_ other:Matrix<T>) throws -> Matrix<T> {
        // require same 1D shapes

        if shape.count != 1 || other.shape.count != 1  {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        var outstorage = [T]()

        for x in storage {
            let row = (0..<other.shape[0] ).map { x - other.storage[$0] }
            outstorage += row 
        }

        return Matrix<T>([shape[0],other.shape[0]], content:outstorage )
    }

    public func multiplyTranspose(_ other:Matrix<T>) throws -> Matrix<T> {
        // require same 1D shapes

        if shape.count != 1 || other.shape.count != 1  {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        var outstorage = [T]()

        for x in storage {
            let row = (0..<other.shape[0]) .map { x * other.storage[$0] }
            outstorage += row 
        }

        return Matrix<T>([shape[0],other.shape[0]], content:outstorage )
    }

    public func divideTranspose(_ other:Matrix<T>) throws -> Matrix<T> {
        // require same 1D shapes

        if shape.count != 1 || other.shape.count != 1  {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        var outstorage = [T]()

        for x in storage {
            let row = (0..<other.shape[0]) .map { ((x as! Double) / (other.storage[$0] as! Double)) as! T }
            outstorage += row 
        }

        return Matrix<T>([shape[0],other.shape[0]], content:outstorage )
    }

    public func subtract( _ other:Matrix<T>) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        //let diff = zip( storage, other.storage ) .map { $0 - $1 }
        let diff = (0..<storage.count) .map { storage[$0] - other.storage[$0] }

        return Matrix<T>(shape, content:diff )

    }

    public func subtract( _ const:T) throws -> Matrix<T> {
        
        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let diff = storage .map { $0 - const }

        return Matrix<T>(shape, content:diff )

    }

    public func multiply( _ other:Matrix<T>) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        //let diff = zip( storage, other.storage ) .map { $0 * $1 }
        let pdct = (0..<storage.count) .map { storage[$0] * other.storage[$0] }

        return Matrix<T>(shape, content:pdct )

    }

    public func multiply( _ const:T) throws -> Matrix<T> {
        
        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let product = storage .map { $0 * const }

        return Matrix<T>(shape, content:product )

    }

    public func divide( _ other:Matrix<T>) throws -> Matrix<T> {
        // require same shape
        if shape != other.shape {
            throw MatrixError.shapeError
        }

        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        
        //let ratio = zip( storage, other.storage ) .map { (($0 as! Double) / ($1 as! Double)) as! T }
        let ratio = (0..<storage.count) .map { ((storage[$0] as! Double) / (other.storage[$0] as! Double)) as! T }
        

        return Matrix<T>(shape, content:ratio )

    }

    public func divide( _ const:T) throws -> Matrix<T> {
        
        if (T.self != Double.self) && (T.self != Int.self) {
            throw MatrixError.typeError
        }

        let ratio = storage .map { (($0 as! Double) / (const as! Double)) as! T }

        return Matrix<T>(shape, content:ratio )

    }

    public func scale( _ scale:Double) throws -> Matrix<T> {
        // 

        if (T.self != Double.self) {
            throw MatrixError.typeError
        }

        let scaled_storage = storage .map { (scale * ($0 as! Double)) as! T }

        return Matrix<T>(shape, content:scaled_storage)

    }

    public func power(_ pwr:Double) throws -> Matrix<T> {
        
        if (T.self != Double.self) {
            throw MatrixError.typeError
        }


        let mod_storage = storage .map { pow($0 as! Double, pwr) as! T }
               

        return Matrix<T>(shape, content:mod_storage)
    }

    public func reciprocal() throws -> Matrix<T> {

        if (T.self != Double.self) {
            throw MatrixError.typeError
        }

        
        let mod_storage = storage .map { (1.0 / ($0 as! Double)) as! T }
        

        return Matrix<T>(shape, content:mod_storage)
    }

    public func applyMask(_ mask:Mask) throws -> ([[Int]],[T]) {
        // returns list of selected indices and corresponding values

        if mask.shape != self.shape {
            throw MatrixError.shapeError
        }

        let indices = self.indicesInOrder()

        var retindices = [[Int]]()
        var retvalues = [T]()

        for vidx in 0..<indices.count {
            let indice = indices[vidx]
            let s = mask.storage[vidx]
            if s {
                retindices.append(indice)
                retvalues.append(self.storage[vidx])
            }
        }
        

        return (retindices,retvalues)


    }

    public func setValueForMask(_ mask:Mask, _ value:T ) throws {
        if mask.shape != self.shape {
            throw MatrixError.shapeError
        }

        mask.storage.enumerated() .map { if $0.element {self.storage[$0.offset] = value } } 
    }

    public func setValueForMask(_ mask:Mask, _ other:Matrix<T> ) throws {
        if mask.shape != self.shape {
            throw MatrixError.shapeError
        }

        if other.shape != self.shape {
            throw MatrixError.shapeError
        }

        mask.storage.enumerated() .map { if $0.element {self.storage[$0.offset] = other.storage[$0.offset] } } 
    }

    public func setdiagonal(_ value:T) throws {
        if shape.count != 2 || shape[0] != shape[1] {
            throw MatrixError.shapeError
        }

        let ndiag = self.storage.count / strides[0]

        for idiag in 0..<ndiag {
            storage[idiag * strides[0] + idiag ] = value 
        }
    }


    public func sum() throws -> Matrix<T> {
        // sum last dimension

        if T.self == Bool.self {
            throw MatrixError.typeError
        }

        if shape.count == 1 {
            throw MatrixError.shapeError
        }

        var zero:Any?

        if T.self == Double.self {
            zero = 0.0
        }
        else if T.self == Int.self {
            zero = 0
        }
        
        let lastdim = shape[shape.count-1]
        let nout = storage.count / lastdim

        let slices = (0..<nout) .map { storage[($0*lastdim)..<(($0+1)*lastdim)] }
        let sumstorage = slices.map { $0.reduce(zero as! T) { $0 + $1 } }

        let outshape = Array(shape[0..<(shape.count-1)])

        return Matrix<T>(outshape, content:sumstorage)
    }

    public func getStorage() -> Array<T> {
        return storage
    }

    public func getStrides() -> [Int] {
        return strides
    }

    public func getShape() -> [Int] {
        return shape
    }
}


public struct Mask {

    var shape:[Int]

    var strides:[Int]

    var count:Int

    var storage:Array<Bool> 

    public init( _ inputshape:[Int], content:[Bool]? = nil  )  {
        shape = inputshape 
        count = 1

        for d in shape {
            count *= d
        }

        strides = [Int]() 

        for sidx in 0..<(shape.count - 1) {
            var str = 1
            for sjdx in (sidx+1)..<shape.count {
                str *= shape[sjdx]
            }
            strides.append(str)
        }

        // always have stride 1 for last dimension

        strides.append(1)

    
        if content == nil {
            storage = Array(repeating:false, count:count)
        }
        else {
            storage = content!
        }
        
        

    }

    func advance (_ indice: inout [Int] ) {
        for pos in (0...(shape.count-1)).reversed() {
            indice[pos] += 1
            if indice[pos] == shape[pos] {
                indice[pos] = 0 
                continue
            }
            return
        }
    }

    public func indicesInOrder() -> [[Int]] {
        var indices = [[Int]]() 

        var currentIndice = Array(repeating:0, count:shape.count)

        for _ in 0..<count {
            indices.append(currentIndice)
            advance( &currentIndice )
        }

        return indices 
    }

    public func nonzero() -> [[Int]] {

        let indices = self.indicesInOrder() 

        var retindices = [[Int]]()

        for k in 0..<indices.count {
            let s = self.storage[k]
            if s {
                retindices.append(indices[k])
            }
        }

        return retindices
    }

    public mutating func setValue(_ indices:[Int], _ value:Bool ) throws {
        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }

            index += idx * strides[sidx]
            if index < 0 || index >= storage.count {
                throw MatrixError.sizeError
            }
        }

        storage[index] = value 
        
    }

    public func getValue(_ indices:[Int] ) throws -> Bool {

        if indices.count != shape.count {
            throw MatrixError.shapeError
        }

        var index = 0

        for (sidx,idx) in indices.enumerated() {
            if idx < 0 || idx >= shape[sidx] {
                throw MatrixError.invalidIndex
            }
            
            index += idx * strides[sidx]

            if index < 0 || index >= storage.count {
                throw MatrixError.sizeError
            }
        }

        return storage[index]
        
    }

    public func logical_and( _ other:Mask ) throws -> Mask {

        if other.shape != self.shape {
            throw MatrixError.shapeError
        }

        //let anded = zip(self.storage, other.storage) .map { $0 && $1 }
        let anded = (0..<self.storage.count) .map { self.storage[$0] && other.storage[$0] }

        return Mask(self.shape, content:anded )

    }

    public func logical_or( _ other:Mask ) throws -> Mask {

        if other.shape != self.shape {
            throw MatrixError.shapeError
        }

        //let ored = zip(self.storage, other.storage) .map { $0 || $1 }

        let ored = (0..<self.storage.count) .map { self.storage[$0] || other.storage[$0] }

        return Mask(self.shape, content:ored )

    }

    public func logical_not()  -> Mask {

        let snot = self.storage .map { !$0 }

        return Mask(self.shape, content:snot )

    }


    public static func compare(_ matA:Matrix<Double>, _ filter: @escaping (Double) -> Bool ) -> Mask {

        let content = matA.storage .map { filter($0) }
        return Mask(matA.shape, content:content )

    }

    public static func compare(_ matA:Matrix<Int>, _ filter: @escaping (Int) -> Bool ) -> Mask {

        let content = matA.storage .map { filter($0) }
        return Mask(matA.shape, content:content )

    }

    public static func compare(_ matA:Matrix<Double>, _ matB:Matrix<Double>, _ filter: @escaping (Double,Double) -> Bool ) throws -> Mask {

        if matA.shape != matB.shape {
            throw MatrixError.shapeError
        }

        //let content = zip(matA.storage, matB.storage) .map { filter($0,$1) }
        let content = (0..<matA.storage.count) .map { filter(matA.storage[$0], matB.storage[$0])}

        return Mask(matA.shape, content:content )

    }

    public static func compare(_ matA:Matrix<Int>, _ matB:Matrix<Int>, _ filter: @escaping (Int,Int) -> Bool ) throws -> Mask {

        if matA.shape != matB.shape {
            throw MatrixError.shapeError
        }

        //let content = zip(matA.storage, matB.storage) .map { filter($0,$1) }

        let content = (0..<matA.storage.count) .map { filter(matA.storage[$0], matB.storage[$0])}
        
        return Mask(matA.shape, content:content )

    }


}


func addBlock(_ BLOCKS: inout [[Double]?], _ block:[Double], _ index:Int, _ offset:Int ) {

    BLOCKS[offset + index] = block

}

func addTupBlock(_ BLOCKS: inout [[[Int]]?], _ block:[[Int]], _ index:Int, _ offset:Int ) {

    BLOCKS[offset + index] = block

}

enum DistError : Error {
    case lastDimensionsDoNotMatch
}

func tupdist(_ A:[Double],_ B:[Double],_ aidx:Int,_ bidx:Int,_ DIM:Int) -> Double {
	return (pow(A[DIM*aidx] - B[bidx*DIM],2) + 
			pow(A[DIM*aidx + 1] - B[bidx*DIM + 1],2) + 
			pow(A[DIM*aidx + 2] - B[bidx*DIM + 2],2)).squareRoot()

}

func storageDistance( _ A:Matrix<Double>, _ B:Matrix<Double>, _ DIM:Int, _ index:Int, 
        _ Alimits:[[Int]], _ Blimits:[[Int]] ) -> ([Double],Int,[[Int]]) {

    let Atuplo = Alimits[index][0] 
    let Atuphi = Alimits[index][1]
    let Btuplo = Blimits[index][0] 
    let Btuphi = Blimits[index][1]

    // have break down this way - a more compact representation with three nested mappings is
    // 'too complicated' for the compiler to interpret !

    let dists = (Atuplo..<Atuphi) .flatMap { (atupidx) in 
        (Btuplo..<Btuphi) .map { tupdist(A.storage, B.storage, atupidx, $0, DIM ) }
    }

    let tups = (Atuplo..<Atuphi) .flatMap { (atupidx) in 
        (Btuplo..<Btuphi) .map { [atupidx, $0]  }
    }


    return (dists,index,tups)
}

func storageOP( _ A:Matrix<Double>, _ Alimits:[[Int]], _ index:Int, _ op:(Double)->Double) -> ([Double],Int) {

    let Alo = Alimits[index][0] 
    let Ahi = Alimits[index][1]

    let res = (Alo..<Ahi) .map { op(A.storage[$0]) }

    return (res,index)

}

func storageOP2( _ A:Matrix<Double>, _ B:Matrix<Double>, _ Alimits:[[Int]], _ index:Int, _ op:(Double,Double)->Double) -> ([Double],Int) {

    let Alo = Alimits[index][0] 
    let Ahi = Alimits[index][1]

    let res = (Alo..<Ahi) .map  { op(A.storage[$0],B.storage[$0]) }

    return (res,index)

}

public func applyOP( _ A:Matrix<Double>, numthreads:Int=1, _ op: @escaping (Double)->Double) throws -> Matrix<Double> {


    let size = Int(floor(Double(A.storage.count)/Double(numthreads)))
    let nsections = Int(ceil(Double(A.storage.count)/Double(size)))

    var chunklimits = [[Int]]()

    

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = A.storage.count
        }
        chunklimits.append([start,end])
    }

    var BLOCKS = [[Double]?](repeating:nil, count:nsections) 

    let group = DispatchGroup() 

    for cidx in 0..<nsections {

                //print("enter thread \(cidx)")
       
                group.enter()

                computeQueue.async {
                        let data = storageOP(A, chunklimits, cidx, op )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, 0  )
                        }
                        group.leave()

                        //print("exit thread \(data.1)")
                    }

            
    } 

    group.wait()

    var content = [Double]()

    for idx in 0..<nsections {
        content += BLOCKS[idx]!
    }

    return Matrix<Double>(A.shape, content:content)
}

public func applyOP2( _ A:Matrix<Double>, _ B:Matrix<Double>, numthreads:Int=1, _ op: @escaping (Double,Double)->Double) throws 
            -> Matrix<Double> {

    if A.shape != B.shape {
        throw MatrixError.shapeError
    }

    let size = Int(floor(Double(A.storage.count)/Double(numthreads)))
    let nsections = Int(ceil(Double(A.storage.count)/Double(size)))

    var chunklimits = [[Int]]()

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = A.storage.count
        }
        chunklimits.append([start,end])
    }

    var BLOCKS = [[Double]?](repeating:nil, count:nsections) 

    let group = DispatchGroup() 

    for cidx in 0..<nsections {
       
                group.enter()

                computeQueue.async {
                        let data = storageOP2(A, B, chunklimits, cidx, op )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, 0  )
                        }
                        group.leave()
                    }

            
    } 

    group.wait()

    var content = [Double]()

    for idx in 0..<nsections {
        content += BLOCKS[idx]!
    }

    return Matrix<Double>(A.shape, content:content)
}

// apply operation 'in place' for slice of Matrix A, using matrix B as input
// Size of slice of A must match B 

public func applyOP2_slice( _ A:Matrix<Double>, _ sliceA:[Range<Int>], _ B:Matrix<Double>,  _ op: @escaping (Double,Double)->Double) throws  {

    var sliceRanges:[Range<Int>]?

    do {
        sliceRanges = try A.getSliceRanges(sliceA)
    }
    catch {
        throw MatrixError.shapeError
    }

    let sliceShape = sliceA .map { $0.upperBound - $0.lowerBound }
    
    if sliceShape != B.shape {
        throw MatrixError.shapeError
    }

    // not sure how to multithread this
    var accum = 0

    for range in sliceRanges! {
            _ = (range.enumerated()).map { A.storage[$0.element] = op(A.storage[$0.element], B.storage[accum + $0.offset]) }
            accum += (range.upperBound - range.lowerBound)
    }

}

public func cdist( _ A:Matrix<Double>, _ B:Matrix<Double>, numthreads:Int=1 ) throws -> Matrix<Double> {
    
    // 

    let DIM = A.shape[A.shape.count-1]

    if B.shape[B.shape.count-1] != DIM {
        throw DistError.lastDimensionsDoNotMatch
    }

    // limits here correspond to DIM-tuples

    var Alimits = [[Int]]()
    var Blimits = [[Int]]()

    let reverse = A.count > B.count 


    let maxTupleCount = max((A.storage.count/DIM),(B.storage.count/DIM))

    let size = Int(floor(Double(maxTupleCount)/Double(numthreads)))
    let nsections = Int(ceil(Double(maxTupleCount)/Double(size)))
     
    var chunklimits = [[Int]]()
    var grpcount = -1

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = maxTupleCount
        }
        chunklimits.append([start,end])
    }
        // need each element of smaller list against chunks of larger list 
        
    if reverse {
        grpcount = B.storage.count/DIM
        for b in 0..<grpcount {
            for clim in chunklimits {
                Blimits.append([b,b+1])
                Alimits.append(clim)
            }
        }
    } else {
        grpcount = A.storage.count/DIM
        for a in 0..<grpcount  {
            for clim in chunklimits {
                Alimits.append([a,a+1])
                Blimits.append(clim)
            }
        }
    }
        

    var BLOCKS = [[Double]?](repeating:nil, count:grpcount*nsections) 
    
    // 

    let group = DispatchGroup()

    for grp in 0..<grpcount {

            let Alim = Array(Alimits[(grp*nsections)..<((grp+1)*nsections)]) 
            let Blim = Array(Blimits[(grp*nsections)..<((grp+1)*nsections)])

             

            for idx in 0..<nsections {

                group.enter()

                computeQueue.async {
                        let data = storageDistance(A, B, DIM, idx, Alim, Blim )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, grp*nsections  )
                        }
                        group.leave()
                    }

                

            }   
        
            

    }

    group.wait()

    // Assemble return array

    var DIST = [Double]()

    for idx in 0..<grpcount*nsections {
        DIST += BLOCKS[idx]!
    }

    // If reversed, 'A' index increase faster, need to rearrange
    // for aidx in 0..<|A| :
    //      append D[aidx + |A|*k], k in 0..< |B|
    if reverse {
        DIST = (0..<(A.count/DIM)) .flatMap { (aidx) in 
                (0..<(B.count/DIM)) .map { DIST[aidx + $0*(A.count/DIM)]} }
    }
    
    // output shape is combination of input shapes, not including the last dimension
    // (usually = 3)

    let outshape = Array(A.shape[0..<A.shape.count-1] + B.shape[0..<B.shape.count-1])
    return Matrix<Double>(outshape, content:DIST)
}



// the following is a testing version of the cdist function, returns a list of tuples corresponding to the 
// linear output storage. 
/*
func cdist_test( _ A:Matrix<Double>, _ B:Matrix<Double>, numthreads:Int=1, testing:Bool = false ) throws -> (Matrix, [[Int]]) {
    
    // 

    print("entering cdist")

    let DIM = A.shape[A.shape.count-1]

    if B.shape[B.shape.count-1] != DIM {
        throw DistError.lastDimensionsDoNotMatch
    }

    // limits here correspond to DIM-tuples

    var Alimits = [[Int]]()
    var Blimits = [[Int]]()

    let reverse = A.count > B.count 

    print("reverse : \(reverse)")

    let maxTupleCount = max((A.storage.count/DIM),(B.storage.count/DIM))

    let size = Int(floor(Double(maxTupleCount)/Double(numthreads)))
    let nsections = Int(ceil(Double(maxTupleCount)/Double(size)))
     
    var chunklimits = [[Int]]()
    var grpcount = -1

    for idx in 0..<nsections {
        let start = idx * size 
        var end = start
        if idx < nsections - 1 {
            end = start + size 
        }
        else {
            end = maxTupleCount
        }
        chunklimits.append([start,end])
    }
        // need each element of smaller list against chunks of larger list 
        
    if reverse {
        grpcount = B.storage.count/DIM
        for b in 0..<grpcount {
            for clim in chunklimits {
                Blimits.append([b,b+1])
                Alimits.append(clim)
            }
        }
    } else {
        grpcount = A.storage.count/DIM
        for a in 0..<grpcount  {
            for clim in chunklimits {
                Alimits.append([a,a+1])
                Blimits.append(clim)
            }
        }
    }
        
   

    print("limits A -- ")
    for lim in Alimits {
        print("\t\(lim)")
    }
    print("limits B -- ")
    for lim in Blimits {
        print("\t\(lim)")
    }

    var BLOCKS = [[Double]?](repeating:nil, count:grpcount*nsections) 
    var tupBLOCKS = [[[Int]]?](repeating:nil, count:grpcount*nsections) 
    
    // 

    for grp in 0..<grpcount {

            let Alim = Array(Alimits[(grp*nsections)..<((grp+1)*nsections)]) 
            let Blim = Array(Blimits[(grp*nsections)..<((grp+1)*nsections)])

            let group = DispatchGroup() 

            for idx in 0..<nsections {

                group.enter()

                print("start section \(idx)")

                computeQueue.async {
                        let data = storageDistance(A, B, DIM, idx, Alim, Blim )

                        blocksQueue.sync {
                            addBlock( &BLOCKS, data.0, data.1, grp*nsections  )
                            addTupBlock( &tupBLOCKS, data.2, data.1, grp*nsections  )
                        }
                        print("finished section \(idx)")
                        group.leave()
                    }

                

            }   
        
            

    }
    group.wait()
    // Assemble return array

    var DIST = [Double]()
    var TUPS = [[Int]]()

    for idx in 0..<grpcount*nsections {
        DIST += BLOCKS[idx]!
        TUPS += tupBLOCKS[idx]!
    }

    // If reversed, 'A' index increase faster, need to rearrange
    // for aidx in 0..<|A| :
    //      append D[aidx + |A|*k], k in 0..< |B|
    if reverse {
        DIST = (0..<(A.count/DIM)) .flatMap { (aidx) in 
                (0..<(B.count/DIM)) .map { DIST[aidx + $0*(A.count/DIM)]} }
        TUPS = (0..<(A.count/DIM)) .flatMap { (aidx) in 
                (0..<(B.count/DIM)) .map { TUPS[aidx + $0*(A.count/DIM)]} }
    }
    
    // output shape is combination of input shapes, not including the last dimension
    // (usually = 3)

    let outshape = Array(A.shape[0..<A.shape.count-1] + B.shape[0..<B.shape.count-1])
    return (Matrix(outshape, content:DIST), TUPS) 
}
*/
